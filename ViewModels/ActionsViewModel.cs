using System.Collections.ObjectModel;
using System.Globalization;
using System.Net.NetworkInformation;
using System.Text.Json;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using CommunityToolkit.Mvvm.ComponentModel;
using SukiUI.Controls;
using SupportCompanion.Helpers;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public partial class ActionsViewModel : ObservableObject, IDisposable
{
    private const string SystemUpdatesVenturaAndAbove =
        "open x-apple.systempreferences:com.apple.preferences.softwareupdate";

    private const string SystemUpdatesBelowVentura = "open /System/Library/PreferencePanes/SoftwareUpdate.prefPane";
    private const string SoftwareUpdateCacheName = "last_software_update_notification.txt";
    private readonly ActionsService _actionsService;
    private readonly NotificationService _notification;
    private readonly Timer _timer;
    [ObservableProperty] private bool _hasUpdates;
    [ObservableProperty] private string _updateCount = "0";

    public ActionsViewModel(ActionsService actionsService, NotificationService notification)
    {
        _actionsService = actionsService;
        _notification = notification;
        HideSupportButton = !App.Config.HiddenActions.Contains("Support");
        HideMmcButton = !App.Config.HiddenActions.Contains("ManagedSoftwareCenter") && App.Config.MunkiMode;
        HideChangePasswordButton = !App.Config.HiddenActions.Contains("ChangePassword");
        HideRebootButton = !App.Config.HiddenActions.Contains("Reboot");
        HideKillAgentButton = !App.Config.HiddenActions.Contains("KillAgent");
        HideSoftwareUpdatesButton = !App.Config.HiddenActions.Contains("SoftwareUpdates");
        HideGatherLogsButton = !App.Config.HiddenActions.Contains("GatherLogs");
        var interval = (int)TimeSpan.FromHours(App.Config.NotificationInterval).TotalMilliseconds;
        if (!App.Config.HiddenActions.Contains("SoftwareUpdates"))
        {
            CheckForUpdates().ConfigureAwait(false);
            _timer = new Timer(UpdatesCallback, null, 0, interval);
        }
    }

    public bool HideSupportButton { get; private set; }
    public bool HideChangePasswordButton { get; private set; }
    public bool HideMmcButton { get; private set; }
    public bool HideRebootButton { get; private set; }
    public bool HideKillAgentButton { get; private set; }
    public bool HideGatherLogsButton { get; private set; }
    public bool HideSoftwareUpdatesButton { get; }

    public void Dispose()
    {
        _timer?.Dispose();
    }

    private async void UpdatesCallback(object state)
    {
        await CheckAndSendUpdateNotification().ConfigureAwait(false);
    }

    private static async Task<bool> CheckForInternetConnection(int timeoutMs = 10000)
    {
        var url = CultureInfo.InstalledUICulture switch
        {
            { Name: var n } when n.StartsWith("fa") => "http://www.aparat.com", // Iran
            { Name: var n } when n.StartsWith("zh") => "http://www.baidu.com", // China
            _ => "http://www.gstatic.com/generate_204"
        };

        try
        {
            using (var client = new HttpClient { Timeout = TimeSpan.FromMilliseconds(timeoutMs) })
            {
                var response = await client.GetAsync(url);
                return response.IsSuccessStatusCode;
            }
        }
        catch
        {
            Logger.LogWithSubsystem("ActionsViewModel", "No network connection", 1);
            return false;
        }
    }

    public async Task KillAgent()
    {
        await _actionsService.KillAgent();
    }

    public async Task ManagedSoftwareCenter()
    {
        await _actionsService.ManagedSoftwareCenter();
    }

    public async Task Reboot()
    {
        await _actionsService.Reboot();
    }

    public async Task OpenSupportPage()
    {
        await _actionsService.OpenSupportPage();
    }

    public async Task OpenSystemUpdates()
    {
        if (Environment.OSVersion.Version.Major >= 13)
            await _actionsService.RunCommandWithoutOutput(
                "open x-apple.systempreferences:com.apple.preferences.softwareupdate");
        else
            await _actionsService.RunCommandWithoutOutput(
                "open /System/Library/PreferencePanes/SoftwareUpdate.prefPane");
    }

    public async Task OpenChangePasswordPage()
    {
        if (App.Config.ChangePasswordMode == "local")
        {
            if (Environment.OSVersion.Version.Major >= 13)
                await _actionsService.RunCommandWithoutOutput(SystemUpdatesVenturaAndAbove);
            else
                await _actionsService.RunCommandWithoutOutput(SystemUpdatesBelowVentura);
        }
        else if (App.Config.ChangePasswordMode == "url" || App.Config.ChangePasswordMode == "SSOExtension")
        {
            // Do we have a network connection?
            if (!await CheckForInternetConnection())
            {
                await SukiHost.ShowToast("Change Password",
                    "No network connection",
                    TimeSpan.FromSeconds(5));
                return;
            }

            if (App.Config.ChangePasswordMode == "url")
            {
                await _actionsService.RunCommandWithoutOutput($"open {App.Config.ChangePasswordUrl}");
            }
            else if (App.Config.ChangePasswordMode == "SSOExtension")
            {
                var ping = new Ping();
                var realm = await _actionsService.RunCommandWithOutput("/usr/bin/app-sso -l --json");
                var realmJson = JsonSerializer.Deserialize<string[]>(realm);
                var realmName = realmJson[0];

                try
                {
                    var response = await ping.SendPingAsync(realmName);

                    if (response.Status == IPStatus.Success)
                        // open the SSO extension with the realm name
                        await _actionsService.RunCommandWithoutOutput($"/usr/bin/app-sso -c {realmName}");
                    else
                        await SukiHost.ShowToast("Change Password",
                            $"Cannot reach {realmName}, make sure to connect to VPN or corporate network.",
                            TimeSpan.FromSeconds(5));
                }
                catch (Exception)
                {
                    await SukiHost.ShowToast("Change Password",
                        "Change request failed for unknown reason",
                        TimeSpan.FromSeconds(5));
                }
            }
            else
            {
                await SukiHost.ShowToast("Change Password",
                    "Change password mode not configured",
                    TimeSpan.FromSeconds(5));
            }
        }
    }

    public async Task GatherLogs()
    {
        var archivePath = "/tmp/supportcompanion_logs.zip";
        var command = $"/usr/bin/zip -r {archivePath}";

        foreach (var folder in App.Config.LogFolders)
            // Ensure each folder path is quoted to handle spaces
            command += $" \'{folder}\'";
        await _actionsService.RunCommandWithoutOutput(command);
        // Check if the zip command was successful
        if (!File.Exists(archivePath))
        {
            await SukiHost.ShowToast("Gather Logs",
                "Failed to gather logs",
                TimeSpan.FromSeconds(5));
            return;
        }

        // Prompt the user for a file save location
        var saveFileDialog = new SaveFileDialog
        {
            Title = "Save Logs",
            InitialFileName = "supportcompanion_logs.zip",
            Filters = new List<FileDialogFilter>
            {
                new() { Name = "Zip Files", Extensions = new List<string> { "zip" } }
            }
        };
        var mainWindow = Application.Current.ApplicationLifetime is ClassicDesktopStyleApplicationLifetime desktop
            ? desktop.MainWindow
            : null;
        var savePath = await saveFileDialog.ShowAsync(mainWindow);
        if (savePath != null)
        {
            File.Move(archivePath, savePath);
            await SukiHost.ShowToast("Gather Logs",
                "Logs saved successfully",
                TimeSpan.FromSeconds(5));
        }
        else
        {
            await SukiHost.ShowToast("Gather Logs",
                "Logs not saved",
                TimeSpan.FromSeconds(5));
        }
    }

    public void ShowSupportInfoDialog()
    {
        SukiHost.ShowDialog(new SupportDialogViewModel(), allowBackgroundClose: true);
    }

    private async Task<bool> CheckForUpdates()
    {
        Logger.LogWithSubsystem("ActionsViewModel", "Checking for software updates...", 1);
        var result = await _actionsService.RunCommandWithOutput("/usr/sbin/softwareupdate -l");
        var lines = result.Split('\n');
        var updates = new ObservableCollection<string>();

        foreach (var line in lines)
            if (line.Contains("*"))
                updates.Add(line);

        if (updates.Count > 0)
        {
            HasUpdates = true;
            UpdateCount = updates.Count.ToString();
            return true; // Updates are available
        }

        return false; // No updates available
    }

    private async Task CheckAndSendUpdateNotification()
    {
        var lastNotificationTime = NotificationTimeStamp.ReadLastNotificationTime(SoftwareUpdateCacheName);
        if (lastNotificationTime.HasValue &&
            (DateTime.Now - lastNotificationTime.Value).TotalHours <
            App.Config.NotificationInterval) return; // Skip sending notification if it's been less than 4 hours

        var updatesAvailable = await CheckForUpdates().ConfigureAwait(false);

        if (updatesAvailable)
        {
            _notification.SendNotification(
                App.Config.SoftwareUpdateNotificationMessage,
                App.Config.SoftwareUpdateNotificationButtonText,
                SystemUpdatesVenturaAndAbove);

            // Update the last notification time
            NotificationTimeStamp.WriteLastNotificationTime(DateTime.Now, SoftwareUpdateCacheName);
        }
    }
}