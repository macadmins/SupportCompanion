using System.Diagnostics;
using SupportCompanion.Services;

namespace SupportCompanion.Helpers;

public class StartProcess
{
    private static readonly ProcessStartInfo DefaultStartInfo = new()
    {
        FileName = "/bin/bash",
        UseShellExecute = false,
        CreateNoWindow = true,
        RedirectStandardOutput = true,
        RedirectStandardError = true
    };

    private readonly LoggerService _logger;

    // Default constructor
    public StartProcess() : this(new LoggerService())
    {
    }

    // Constructor with LoggerService parameter
    private StartProcess(LoggerService logger)
    {
        _logger = logger;
    }

    private ProcessStartInfo CreateStartInfo(string command)
    {
        return new ProcessStartInfo
        {
            FileName = DefaultStartInfo.FileName,
            Arguments = $"-c \"{command}\"",
            UseShellExecute = DefaultStartInfo.UseShellExecute,
            CreateNoWindow = DefaultStartInfo.CreateNoWindow,
            RedirectStandardOutput = DefaultStartInfo.RedirectStandardOutput,
            RedirectStandardError = DefaultStartInfo.RedirectStandardError
        };
    }

    public async Task<string> RunCommand(string command)
    {
        if (string.IsNullOrWhiteSpace(command))
            _logger.Log("StartProcess", "Command must not be null or whitespace", 2);

        var startInfo = CreateStartInfo(command);
        using var process = new Process { StartInfo = startInfo };

        process.Start();

        var output = await Task.WhenAll(
            process.StandardOutput.ReadToEndAsync(),
            process.StandardError.ReadToEndAsync()
        );

        await process.WaitForExitAsync();

        if (process.ExitCode != 0)
            _logger.Log("StartProcess",
                $"Command {command} failed with exit code {process.ExitCode}\nError: {output[1]}", 2);

        return output[0].Trim();
    }

    public async Task RunCommandWithoutOutput(string command)
    {
        if (string.IsNullOrWhiteSpace(command))
            _logger.Log("StartProcess", "Command must not be null or whitespace", 2);

        var startInfo = CreateStartInfo(command);
        using var process = new Process { StartInfo = startInfo };

        process.Start();
        await process.WaitForExitAsync();

        if (process.ExitCode != 0)
        {
            var error = await process.StandardError.ReadToEndAsync();
            _logger.Log("StartProcess",
                $"Command {command} failed with exit code {process.ExitCode}\nError: {error}", 2);
        }
    }
}