using System.Diagnostics;

namespace SupportCompanion.Helpers;

public class StartProcess
{
    private string Result { get; set; } = string.Empty;

    public async Task<string> RunCommand(string command)
    {
        if (string.IsNullOrWhiteSpace(command))
            throw new ArgumentException("Value cannot be null or whitespace.", nameof(command));
        var startInfo = new ProcessStartInfo
        {
            FileName = "/bin/bash",
            Arguments = $"-c \"{command}\"",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        using var process = new Process { StartInfo = startInfo };

        process.Start();
        Result = await process.StandardOutput.ReadToEndAsync();
        await process.WaitForExitAsync();

        if (process.ExitCode != 0)
        {
            Logger.LogWithSubsystem("StartProcess", $"Command {command} failed with exit code {process.ExitCode}", 2);
            throw new Exception($"Command {command} failed with exit code {process.ExitCode}");
        }

        return Result.Trim();
    }

    public async Task RunCommandWithoutOutput(string command)
    {
        if (string.IsNullOrWhiteSpace(command))
            throw new ArgumentException("Command must not be null or whitespace", nameof(command));

        var startInfo = new ProcessStartInfo
        {
            FileName = "/bin/bash",
            Arguments = $"-c \"{command}\"",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        using var process = new Process { StartInfo = startInfo };

        process.Start();
        await process.WaitForExitAsync();

        if (process.ExitCode != 0)
        {
            Logger.LogWithSubsystem("StartProcess", $"Command {command} failed with exit code {process.ExitCode}", 2);
            throw new Exception($"Command {command} failed with exit code {process.ExitCode}");
        }
    }
}