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
    private readonly MunkiAppsService _munkiApps;
    private readonly NotificationService _notification;
    private IList _pendingAppsList = new List<string>();
    private readonly Timer _timer;

    public MunkiPendingAppsViewModel(MunkiAppsService munkiApps, NotificationService notification)
    {
        _timer = new Timer(MunkiPendingAppsCallback, null, 0, 60000);
        _munkiApps = munkiApps;
        _notification = notification;
        var interval = (int)TimeSpan.FromHours(App.Config.NotificationInterval).TotalMilliseconds;
        _timer = new Timer(NotificationCallback, null, 0, interval);
    }

    public ObservableCollection<PendingApp> PendingApps { get; } = new();

    public void Dispose()
    {
        _timer?.Dispose();
    }

    private async void MunkiPendingAppsCallback(object state)
    {
        await GetPendingApps();
    }

    private async void NotificationCallback(object state)
    {
        await SendNotification();
    }

    private async Task GetPendingApps()
    {
        Logger.LogWithSubsystem("MunkiPendingAppsViewModel", "Getting pending apps list.", 1);
        _pendingAppsList = await _munkiApps.GetPendingUpdatesList();
        var pendingAppsList = new List<PendingApp>();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            PendingApps.Clear();
            foreach (var app in _pendingAppsList)
            {
                var appDict = (IDictionary<string, object>)app;
                var name = appDict["display_name"].ToString();
                var version = appDict["version_to_install"].ToString();
                PendingApps.Add(new PendingApp(name, version));
            }
        });
    }

    private async Task SendNotification()
    {
        _pendingAppsList = await _munkiApps.GetPendingUpdatesList();
        if (_pendingAppsList.Count == 0) return;
        _notification.SendNotification(
            App.Config.AppUpdateNotificationMessage,
            App.Config.AppUpdateNotificationButtonText,
            OpenMmcUpdates);
    }

    public async Task MmcUpdates()
    {
        var helper = new StartProcess();
        await helper.RunCommandWithoutOutput(OpenMmcUpdates);
    }
}