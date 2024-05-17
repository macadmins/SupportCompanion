using System.Collections;
using System.Collections.ObjectModel;
using Avalonia.Threading;
using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MunkiPendingAppsViewModel : IDisposable
{
    private const string OpenMmcUpdates = "open munki://updates.html";
    private const string AppUpdateNotificationCache = "last_app_update_notification_time.txt";
    private readonly MunkiAppsService _munkiApps;
    private readonly NotificationService _notification;
    private readonly Timer _notificationTimer;
    private readonly Timer _pendingAppsTimer;
    private IList _pendingAppsList = new List<string>();

    public MunkiPendingAppsViewModel(MunkiAppsService munkiApps, NotificationService notification)
    {
        _pendingAppsTimer = new Timer(MunkiPendingAppsCallback, null, 0, 60000);
        _munkiApps = munkiApps;
        _notification = notification;
        var interval = (int)TimeSpan.FromHours(App.Config.NotificationInterval).TotalMilliseconds;
        _notificationTimer = new Timer(NotificationCallback, null, 0, interval);
    }

    public ObservableCollection<MunkiPendingApp> PendingApps { get; } = new();

    public void Dispose()
    {
        _pendingAppsTimer.Dispose();
        _notificationTimer.Dispose();
    }

    private async void MunkiPendingAppsCallback(object state)
    {
        if (App.Config.MunkiMode)
            await GetPendingApps();
    }

    private async void NotificationCallback(object state)
    {
        if (App.Config.MunkiMode)
            await SendNotification().ConfigureAwait(false);
    }

    private async Task GetPendingApps()
    {
        Logger.LogWithSubsystem("MunkiPendingAppsViewModel", "Getting pending apps list.", 1);
        _pendingAppsList = await _munkiApps.GetPendingUpdatesList();
        var pendingAppsList = new List<MunkiPendingApp>();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            PendingApps.Clear();
            foreach (var app in _pendingAppsList)
            {
                var appDict = (IDictionary<string, object>)app;
                var name = appDict["display_name"].ToString();
                var version = appDict["version_to_install"].ToString();
                PendingApps.Add(new MunkiPendingApp(name, version));
            }
        });
    }

    private async Task SendNotification()
    {
        var lastNotificationTime = NotificationTimeStamp.ReadLastNotificationTime(AppUpdateNotificationCache);
        if (lastNotificationTime.HasValue &&
            (DateTime.Now - lastNotificationTime.Value).TotalHours <
            App.Config.NotificationInterval) return; // Skip sending notification if it's been less than 4 hours
        _pendingAppsList = await _munkiApps.GetPendingUpdatesList();
        if (_pendingAppsList.Count == 0) return;
        _notification.SendNotification(
            App.Config.AppUpdateNotificationMessage,
            App.Config.AppUpdateNotificationButtonText,
            OpenMmcUpdates);
        // Update the last notification time
        NotificationTimeStamp.WriteLastNotificationTime(DateTime.Now, AppUpdateNotificationCache);
    }

    public async Task MmcUpdates()
    {
        var helper = new StartProcess();
        await helper.RunCommandWithoutOutput(OpenMmcUpdates);
    }
}