using System.Collections;
using SupportCompanion.Services;

namespace SupportCompanion.Helpers;

public class UpdateNotifications
{
    private const string OpenMmcUpdates = "open munki://updates.html";
    private const string OpenCompanyPortal = "open companyportal://";
    private const string AppUpdateNotificationCache = "last_app_update_notification_time.txt";
    private const string SoftwareUpdateNotificationCache = "last_software_update_notification.txt";
    private readonly ActionsService _actionsService;
    private readonly IntuneAppsService _intuneAppsService;
    private readonly MunkiAppsService _munkiAppsService;
    private readonly NotificationService _notificationService;
    private Timer _appUpdateTimer;
    private IList _pendingAppsList = new List<string>();
    private Timer _softwareUpdateTimer;

    public UpdateNotifications(
        ActionsService actionsService,
        NotificationService notificationService,
        MunkiAppsService munkiAppsService,
        IntuneAppsService intuneAppsService)
    {
        _actionsService = actionsService;
        _notificationService = notificationService;
        _munkiAppsService = munkiAppsService;
        _intuneAppsService = intuneAppsService;
        StartTimers();
    }

    private void StartTimers()
    {
        var interval = (int)TimeSpan.FromHours(App.Config.NotificationInterval).TotalMilliseconds;
        if (!App.Config.HiddenActions.Contains("SoftwareUpdates"))
            _softwareUpdateTimer = new Timer(SoftwareUpdateNotificationCallback, null, 0, interval);
        if (!App.Config.HiddenActions.Contains("IntunePendingApps") ||
            !App.Config.HiddenActions.Contains("MunkiPendingApps"))
            _appUpdateTimer = new Timer(AppUpdateNotificationCallback, null, 0, interval);
    }

    private async void SoftwareUpdateNotificationCallback(object state)
    {
        await CheckAndSendSoftwareUpdateNotification();
    }

    private async void AppUpdateNotificationCallback(object state)
    {
        if (App.Config.MunkiMode)
            await CheckAndSendMunkiAppUpdateNotification();
        if (App.Config.IntuneMode)
            await CheckAndSendIntuneAppUpdateNotification();
    }

    private async Task CheckAndSendSoftwareUpdateNotification()
    {
        try
        {
            var lastNotificationTime = NotificationTimeStamp.ReadLastNotificationTime(SoftwareUpdateNotificationCache);
            if (lastNotificationTime.HasValue &&
                (DateTime.Now - lastNotificationTime.Value).TotalHours < App.Config.NotificationInterval) return;

            var (updatesAvailable, updateCount) = await _actionsService.CheckForUpdates().ConfigureAwait(false);

            if (updatesAvailable)
            {
                _notificationService.SendNotification(
                    App.Config.SoftwareUpdateNotificationMessage,
                    App.Config.SoftwareUpdateNotificationButtonText,
                    "open x-apple.systempreferences:com.apple.preferences.softwareupdate");

                NotificationTimeStamp.WriteLastNotificationTime(DateTime.Now, SoftwareUpdateNotificationCache);
            }
        }
        catch (Exception ex)
        {
            Logger.LogWithSubsystem("CheckAndSendSoftwareUpdateNotification", $"An error occurred: {ex.Message}", 3);
        }
    }

    private async Task CheckAndSendMunkiAppUpdateNotification()
    {
        try
        {
            var lastNotificationTime = NotificationTimeStamp.ReadLastNotificationTime(AppUpdateNotificationCache);
            if (lastNotificationTime.HasValue &&
                (DateTime.Now - lastNotificationTime.Value).TotalHours <
                App.Config.NotificationInterval) return; // Skip sending notification if it's been less than 4 hours
            _pendingAppsList = await _munkiAppsService.GetPendingUpdatesList();
            if (_pendingAppsList.Count == 0) return;
            _notificationService.SendNotification(
                App.Config.AppUpdateNotificationMessage,
                App.Config.AppUpdateNotificationButtonText,
                OpenMmcUpdates);
            // Update the last notification time
            NotificationTimeStamp.WriteLastNotificationTime(DateTime.Now, AppUpdateNotificationCache);

            _pendingAppsList.Clear();
        }
        catch (Exception ex)
        {
            Logger.LogWithSubsystem("CheckAndSendMunkiAppUpdateNotification", $"An error occurred: {ex.Message}", 3);
        }
    }

    private async Task CheckAndSendIntuneAppUpdateNotification()
    {
        try
        {
            var lastNotificationTime = NotificationTimeStamp.ReadLastNotificationTime(AppUpdateNotificationCache);
            if (lastNotificationTime.HasValue &&
                (DateTime.Now - lastNotificationTime.Value).TotalHours <
                App.Config.NotificationInterval) return; // Skip sending notification if it's been less than 4 hours
            var policies = await _intuneAppsService.GetIntuneApps();
            foreach (var app in policies)
                if (app.Value.ComplianceStateMessage.Applicability == 0
                    && app.Value.EnforcementStateMessage.EnforcementState == 1000)
                    policies.Remove(app.Key);
            if (policies.Count == 0) return;
            _notificationService.SendNotification(
                App.Config.AppUpdateNotificationMessage,
                App.Config.AppUpdateNotificationButtonText,
                OpenCompanyPortal);
            // Update the last notification time
            NotificationTimeStamp.WriteLastNotificationTime(DateTime.Now, AppUpdateNotificationCache);

            policies.Clear();
        }
        catch (Exception ex)
        {
            Logger.LogWithSubsystem("CheckAndSendIntuneAppUpdateNotification", $"An error occurred: {ex.Message}", 3);
        }
    }
}