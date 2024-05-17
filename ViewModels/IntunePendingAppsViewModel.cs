using System.Collections.ObjectModel;
using Avalonia.Threading;
using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class IntunePendingAppsViewModel : IDisposable
{
    private const string OpenCompanyPortal = "open companyportal://";
    private const string AppUpdateNotificationCache = "last_app_update_notification_time.txt";
    private readonly ActionsService _actions;
    private readonly IntuneAppsService _intuneApps;
    private readonly NotificationService _notification;
    private readonly Timer _notificationTimer;
    private readonly Timer _pendingAppsTimer;
    private Dictionary<string, IntunePendingApp> _lastFetchedApps = new();
    private bool _showInfoIcon = true;

    public IntunePendingAppsViewModel(IntuneAppsService intuneApps, ActionsService actions,
        NotificationService notification)
    {
        _pendingAppsTimer = new Timer(IntunePendingAppsCallback, null, 0, 60000);
        _intuneApps = intuneApps;
        _actions = actions;
        _notification = notification;
        var interval = (int)TimeSpan.FromHours(App.Config.NotificationInterval).TotalMilliseconds;
        _notificationTimer = new Timer(NotificationCallback, null, 0, interval);
    }

    public ObservableCollection<IntunePendingApp> PendingApps { get; } = new();

    public void Dispose()
    {
        _pendingAppsTimer?.Dispose();
        _notificationTimer?.Dispose();
    }

    private async void IntunePendingAppsCallback(object state)
    {
        if (App.Config.IntuneMode)
            await GetPendingApps();
    }

    private async void NotificationCallback(object state)
    {
        if (App.Config.IntuneMode)
            await SendNotification().ConfigureAwait(false);
    }

    private async Task GetPendingApps()
    {
        Logger.LogWithSubsystem("IntunePendingAppsViewModel", "Getting pending apps list.", 1);
        var policies = await _intuneApps.GetIntuneApps();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            PendingApps.Clear();
            foreach (var app in policies)
                if (app.Value.ComplianceStateMessage.Applicability == 0
                    && app.Value.EnforcementStateMessage.EnforcementState != 1000)
                {
                    if (string.IsNullOrEmpty(app.Value.ErrorDetails)) _showInfoIcon = false;
                    PendingApps.Add(new IntunePendingApp
                    {
                        Name = app.Value.ApplicationName,
                        PendingReason = app.Value.ErrorDetails,
                        ShowInfoIcon = _showInfoIcon
                    });
                }
        });
    }

    private async Task SendNotification()
    {
        var lastNotificationTime = NotificationTimeStamp.ReadLastNotificationTime(AppUpdateNotificationCache);
        if (lastNotificationTime.HasValue &&
            (DateTime.Now - lastNotificationTime.Value).TotalHours <
            App.Config.NotificationInterval) return; // Skip sending notification if it's been less than 4 hours
        var policies = await _intuneApps.GetIntuneApps();
        foreach (var app in policies)
            if (app.Value.ComplianceStateMessage.Applicability == 0
                && app.Value.EnforcementStateMessage.EnforcementState == 1000)
                policies.Remove(app.Key);
        if (policies.Count == 0) return;
        _notification.SendNotification(
            App.Config.AppUpdateNotificationMessage,
            App.Config.AppUpdateNotificationButtonText,
            OpenCompanyPortal);
        // Update the last notification time
        NotificationTimeStamp.WriteLastNotificationTime(DateTime.Now, AppUpdateNotificationCache);
    }

    public async Task CompanyPortal()
    {
        await _actions.RunCommandWithoutOutput(OpenCompanyPortal);
    }
}