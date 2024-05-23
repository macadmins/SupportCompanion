using System.Collections;
using PropertyList;
using SupportCompanion.Services;

namespace SupportCompanion.Helpers;

public class MunkiApps
{
    private readonly LoggerService _logger;
    private readonly string _managedInstallsReportPlist = "/Library/Managed Installs/ManagedInstallReport.plist";
    private readonly string _selfServeManifest = "/Library/Managed Installs/manifests/SelfServeManifest";

    // Default constructor
    public MunkiApps() : this(new LoggerService())
    {
    }

    // Constructor with LoggerService parameter
    private MunkiApps(LoggerService logger)
    {
        _logger = logger;
    }

    private async Task<Stream?> ReadFileWithRetry(string filePath, int maxRetries = 3,
        int delayMilliseconds = 20000)
    {
        for (var i = 0; i < maxRetries; i++)
            try
            {
                return File.Open(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            }
            catch (IOException)
            {
                // Wait before retrying
                _logger.Log(
                    "ReadFileWithRetry",
                    $"File {filePath} is not available. Retrying in {delayMilliseconds} milliseconds.",
                    1);
                await Task.Delay(delayMilliseconds);
            }

        // If we've tried to open the file maxRetries times and it's still not available, log an error and return null
        _logger.Log("ReadFileWithRetry",
            $"File {filePath} could not be opened after {maxRetries} attempts.", 2);
        return null;
    }

    private async Task LookForFileWithRetry(string filePath, int maxRetries = 3, int delayMilliseconds = 20000)
    {
        for (var i = 0; i < maxRetries; i++)
            if (File.Exists(filePath))
            {
                return;
            }
            else
            {
                // Wait before retrying
                _logger.Log(
                    "LookForFileWithRetry",
                    $"File {filePath} is not available. Retrying in {delayMilliseconds} milliseconds.",
                    1);
                await Task.Delay(delayMilliseconds);
            }

        // If we've tried to open the file maxRetries times and it's still not available, log an error and return null
        _logger.Log("LookForFileWithRetry",
            $"File {filePath} could not be found after {maxRetries} attempts.", 2);
    }

    public async Task<int> GetPendingUpdates()
    {
        await LookForFileWithRetry(_managedInstallsReportPlist);
        await using var reader = await ReadFileWithRetry(_managedInstallsReportPlist);
        if (reader == null)
        {
            _logger.Log("MunkiApps:GetPendingUpdates", "Reader is null", 1);
            return 0;
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (plist.TryGetValue("ItemsToInstall", out var pendingApps))
            return ((IList)pendingApps).Count;

        _logger.Log("MunkiApps:GetPendingUpdates", "ItemsToInstall key not found", 1);
        return 0;
    }

    public async Task<int> GetInstalledAppsCount()
    {
        await LookForFileWithRetry(_managedInstallsReportPlist);
        await using var reader = await ReadFileWithRetry(_managedInstallsReportPlist);
        if (reader == null)
        {
            _logger.Log("MunkiApps:GetInstalledAppCount", "Reader is null", 1);
            return 0;
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (plist.TryGetValue("InstalledItems", out var installedApps))
            return ((IList)installedApps).Count;

        _logger.Log("MunkiApps:GetInstalledAppCount", "InstalledItems key not found", 1);
        return 0;
    }

    public async Task<IList> GetPendingUpdatesList()
    {
        await LookForFileWithRetry(_managedInstallsReportPlist);
        await using var reader = await ReadFileWithRetry(_managedInstallsReportPlist);
        if (reader == null)
        {
            _logger.Log("MunkiApps:GetPendingUpdatesList", "Reader is null", 1);
            return new List<string>();
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (plist.TryGetValue("ItemsToInstall", out var pendingApps))
            return (IList)pendingApps;

        _logger.Log("MunkiApps:GetPendingUpdatesList", "ItemsToInstall key not found", 1);
        return new List<string>();
    }

    public async Task<IList> GetInstalledAppsList()
    {
        await LookForFileWithRetry(_managedInstallsReportPlist);
        await using var reader = await ReadFileWithRetry(_managedInstallsReportPlist);
        if (reader == null)
        {
            _logger.Log("MunkiApps:GetInstalledAppsList", "Reader is null", 1);
            return new List<string>();
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (plist.TryGetValue("ManagedInstalls", out var installedApps))
            return (IList)installedApps;

        _logger.Log("MunkiApps:GetInstalledAppsList", "ManagedInstalls key not found", 1);
        return new List<string>();
    }

    public async Task<IList> GetSelfServeAppsList()
    {
        await LookForFileWithRetry(_selfServeManifest);
        await using var reader = await ReadFileWithRetry(_selfServeManifest);
        if (reader == null)
        {
            _logger.Log("MunkiApps:GetSelfServeAppsList", "Reader is null", 1);
            return new List<string>();
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (plist.TryGetValue("managed_installs", out var selfServeApps))
            return (IList)selfServeApps;

        _logger.Log("MunkiApps:GetSelfServeAppsList", "managed_installs key not found", 1);
        return new List<string>();
    }
}