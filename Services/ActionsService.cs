using System.Collections.ObjectModel;
using System.Diagnostics;
using SukiUI.Controls;
using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class ActionsService : IActions
{
    private const string OpenManagedSoftwareCenter = "open -a /Applications/Managed\\ Software\\ Center.app";
    private const string OpenMmcUpdates = "open munki://updates.html";

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
            Logger.LogWithSubsystem("ActionsService:KillAgent", $"Failed to kill agent: {error}", 2);
            await SukiHost.ShowToast("Kill Agent", "Failed to kill agent", TimeSpan.FromSeconds(5));
        }

        await SukiHost.ShowToast("Kill Agent", "Agent successfully killed", TimeSpan.FromSeconds(5));
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
            Logger.LogWithSubsystem("ActionsService:Reboot", $"Reboot failed: {error}", 2);
            await SukiHost.ShowToast("Reboot", "Reboot failed", TimeSpan.FromSeconds(5));
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
        Logger.LogWithSubsystem("ActionsViewModel", "Checking for software updates...", 1);
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