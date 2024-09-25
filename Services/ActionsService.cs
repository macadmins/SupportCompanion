using System.Collections.ObjectModel;
using System.Diagnostics;
using Avalonia.Controls.Notifications;
using SukiUI.Toasts;
using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class ActionsService : IActions
{
    private const string OpenManagedSoftwareCenter = "open -a /Applications/Managed\\ Software\\ Center.app";
    private const string OpenMmcUpdates = "open munki://updates.html";
    private readonly LoggerService _logger;

    public ActionsService(LoggerService loggerService, ISukiToastManager toastManager)
    {
        _logger = loggerService;
        ToastManager = toastManager;
    }

    public ISukiToastManager ToastManager { get; }

    public async Task KillAgent()
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "/usr/bin/osascript",
            Arguments = "-e \"do shell script \\\"sudo killall IntuneMdmAgent\\\" with administrator privileges\"",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = new Process { StartInfo = startInfo };
        process.Start();
        var error = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();

        if (process.ExitCode != 0)
        {
            _logger.Log("ActionsService:KillAgent", $"Failed to kill agent: {error}", 2);
            ToastManager.CreateSimpleInfoToast()
                .WithTitle("Kill Agent")
                .OfType(NotificationType.Error)
                .WithContent("Failed to kill agent")
                .Queue();
        }
        else
        {
            ToastManager.CreateSimpleInfoToast()
                .WithTitle("Kill Agent")
                .OfType(NotificationType.Success)
                .WithContent("Agent successfully killed")
                .Queue();
        }
    }

    public async Task Reboot()
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "/usr/bin/osascript",
            Arguments = "-e \"do shell script \\\"sudo shutdown -r now\\\" with administrator privileges\"",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = new Process { StartInfo = startInfo };
        process.Start();
        var error = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();

        if (process.ExitCode != 0)
        {
            _logger.Log("ActionsService:Reboot", $"Reboot failed: {error}", 2);
            ToastManager.CreateSimpleInfoToast()
                .WithTitle("Reboot")
                .OfType(NotificationType.Error)
                .WithContent("Reboot failed")
                .Queue();
        }
    }

    public async Task ManagedSoftwareCenter()
    {
        var helper = new StartProcess();
        await helper.RunCommandWithoutOutput(OpenManagedSoftwareCenter);
    }

    public async Task MmcUpdates()
    {
        var helper = new StartProcess();
        await helper.RunCommandWithoutOutput(OpenMmcUpdates);
    }

    public async Task OpenSupportPage()
    {
        var command = $"open {App.Config.SupportPageUrl}";
        var helper = new StartProcess();
        await helper.RunCommandWithoutOutput(command);
    }

    public async Task RunCommandWithoutOutput(string command)
    {
        var helper = new StartProcess();
        await helper.RunCommandWithoutOutput(command);
    }

    public async Task<string> RunCommandWithOutput(string command)
    {
        var helper = new StartProcess();
        var result = await helper.RunCommand(command);
        return result;
    }

    public async Task<(bool, string)> CheckForUpdates()
    {
        _logger.Log("ActionsViewModel", "Checking for software updates...", 1);
        var helper = new StartProcess();
        var result = await helper.RunCommand("/usr/sbin/softwareupdate -l");
        var lines = result.Split('\n');
        var updates = new ObservableCollection<string>();

        foreach (var line in lines)
            if (line.Contains("*"))
                updates.Add(line);

        if (updates.Count > 0) return (true, updates.Count.ToString()); // Updates are available

        return (false, string.Empty); // No updates available
    }
}