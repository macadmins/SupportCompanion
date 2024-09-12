using System.Globalization;
using System.Net.NetworkInformation;
using System.Text.Json;
using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using SukiUI.Controls;
using SupportCompanion.Interfaces;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public partial class ActionsViewModel : ObservableObject, IWindowStateAware
{
    private const string SystemUpdatesVenturaAndAbove =
        "open x-apple.systempreferences:com.apple.preferences.softwareupdate";

    private const string SystemUpdatesBelowVentura = "open /System/Library/PreferencePanes/SoftwareUpdate.prefPane";
    private const string ChangePasswordLocal = "open /System/Library/PreferencePanes/Accounts.prefPane";
    private readonly ActionsService _actionsService;
    private readonly LoggerService _logger;
    [ObservableProperty] private bool _hasUpdates;
    [ObservableProperty] private string _updateCount = "0";

    public ActionsViewModel(ActionsService actionsService, LoggerService loggerService)
    {
        _actionsService = actionsService;
        _logger = loggerService;
        HideSupportButton = !App.Config.HiddenActions.Contains("Support");
        HideMmcButton = !App.Config.HiddenActions.Contains("ManagedSoftwareCenter") && App.Config.MunkiMode;
        HideChangePasswordButton = !App.Config.HiddenActions.Contains("ChangePassword");
        HideRebootButton = !App.Config.HiddenActions.Contains("Reboot");
        HideKillAgentButton = !App.Config.HiddenActions.Contains("KillAgent");
        HideSoftwareUpdatesButton = !App.Config.HiddenActions.Contains("SoftwareUpdates");
        HideGatherLogsButton = !App.Config.HiddenActions.Contains("GatherLogs");
        if (!App.Config.HiddenWidgets.Contains("Actions")) Dispatcher.UIThread.Post(InitializeAsync);
    }

    public bool HideSupportButton { get; private set; }
    public bool HideChangePasswordButton { get; private set; }
    public bool HideMmcButton { get; private set; }
    public bool HideRebootButton { get; private set; }
    public bool HideKillAgentButton { get; private set; }
    public bool HideGatherLogsButton { get; private set; }
    public bool HideSoftwareUpdatesButton { get; }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        if (!App.Config.HiddenActions.Contains("SoftwareUpdates"))
            Dispatcher.UIThread.Post(InitializeAsync);
    }

    private async void InitializeAsync()
    {
        await CheckSoftwareUpdates();
    }

    private async Task CheckSoftwareUpdates()
    {
        var (hasUpdates, updateCount) = await _actionsService.CheckForUpdates().ConfigureAwait(false);
        HasUpdates = hasUpdates;
        UpdateCount = updateCount;
    }

    private async Task<bool> CheckForInternetConnection(int timeoutMs = 10000)
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
            _logger.Log("ActionsViewModel", "No network connection", 1);
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
            await _actionsService.RunCommandWithoutOutput(ChangePasswordLocal);
        }
        else if (App.Config.ChangePasswordMode == "url" || App.Config.ChangePasswordMode == "SSOExtension")
        {
            // Do we have a network connection?
            if (!await CheckForInternetConnection())
            {
                await SukiHost.ShowToast("Change Password",
                    "No network connection");
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
                            $"Cannot reach {realmName}, make sure to connect to VPN or corporate network.");
                }
                catch (Exception)
                {
                    await SukiHost.ShowToast("Change Password",
                        "Change request failed for unknown reason");
                }
            }
            else
            {
                await SukiHost.ShowToast("Change Password",
                    "Change password mode not configured");
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
                "Failed to gather logs");
            return;
        }

        // Prompt the user for a file save location
        var mainWindow = Application.Current.ApplicationLifetime is ClassicDesktopStyleApplicationLifetime desktop
            ? desktop.MainWindow
            : null;

        if (mainWindow != null)
        {
            var storageFile = await mainWindow.StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "Save Logs",
                SuggestedFileName = "supportcompanion_logs.zip",
                DefaultExtension = "zip"
            });

            if (storageFile != null)
            {
                await using (var sourceStream = new FileStream(archivePath, FileMode.Open, FileAccess.Read))
                await using (var destinationStream = await storageFile.OpenWriteAsync())
                {
                    await sourceStream.CopyToAsync(destinationStream);
                }

                File.Delete(archivePath); // Delete the source file after successful copy

                await SukiHost.ShowToast("Gather Logs",
                    "Logs saved successfully");
            }
            else
            {
                await SukiHost.ShowToast("Gather Logs",
                    "Logs not saved");
            }
        }
    }

    public void ShowSupportInfoDialog()
    {
        SukiHost.ShowDialog(new SupportDialogViewModel(), allowBackgroundClose: true);
    }

    private void CleanUp()
    {
        // No cleanup needed
    }
}