using System.Collections;
using PropertyList;

namespace SupportCompanion.Helpers;

public class MunkiApps
{
    private readonly string _managedInstallsReportPlist = "/Library/Managed Installs/ManagedInstallReport.plist";
    private readonly string _selfServeManifest = "/Library/Managed Installs/manifests/SelfServeManifest";

    private static async Task<Stream> ReadFileWithRetry(string filePath, int maxRetries = 3,
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
                Logger.LogWithSubsystem(
                    "ReadFileWithRetry",
                    $"File {filePath} is not available. Retrying in {delayMilliseconds} milliseconds.",
                    1);
                await Task.Delay(delayMilliseconds);
            }

        // If we've tried to open the file maxRetries times and it's still not available, log an error and return null
        Logger.LogWithSubsystem("ReadFileWithRetry",
            $"File {filePath} could not be opened after {maxRetries} attempts.", 2);
        return null;
    }

    private static async Task LookForFileWithRetry(string filePath, int maxRetries = 3, int delayMilliseconds = 20000)
    {
        for (var i = 0; i < maxRetries; i++)
            if (File.Exists(filePath))
            {
                return;
            }
            else
            {
                // Wait before retrying
                Logger.LogWithSubsystem(
                    "LookForFileWithRetry",
                    $"File {filePath} is not available. Retrying in {delayMilliseconds} milliseconds.",
                    1);
                await Task.Delay(delayMilliseconds);
            }

        // If we've tried to open the file maxRetries times and it's still not available, log an error and return null
        Logger.LogWithSubsystem("LookForFileWithRetry",
            $"File {filePath} could not be found after {maxRetries} attempts.", 2);
    }

    public async Task<int> GetPendingUpdates()
    {
        await LookForFileWithRetry(_managedInstallsReportPlist);
        await using var reader = await ReadFileWithRetry(_managedInstallsReportPlist);
        if (reader == null)
        {
            Logger.LogWithSubsystem("MunkiApps:GetPendingUpdates", "Reader is null", 1);
            return 0;
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (!plist.ContainsKey("ItemsToInstall"))
        {
            Logger.LogWithSubsystem("MunkiApps:GetPendingUpdates", "ItemsToInstall key not found", 1);
            return 0;
        }

        var pendingApps = (IList)plist["ItemsToInstall"];
        return pendingApps.Count;
    }

    public async Task<int> GetInstalledAppsCount()
    {
        await LookForFileWithRetry(_managedInstallsReportPlist);
        await using var reader = await ReadFileWithRetry(_managedInstallsReportPlist);
        if (reader == null)
        {
            Logger.LogWithSubsystem("MunkiApps:GetInstalledAppCount", "Reader is null", 1);
            return 0;
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (!plist.ContainsKey("InstalledItems"))
        {
            Logger.LogWithSubsystem("MunkiApps:GetInstalledAppCount", "InstalledItems key not found", 1);
            return 0;
        }

        var installedApps = (IList)plist["InstalledItems"];
        return installedApps.Count;
    }

    public async Task<IList> GetPendingUpdatesList()
    {
        await LookForFileWithRetry(_managedInstallsReportPlist);
        await using var reader = await ReadFileWithRetry(_managedInstallsReportPlist);
        if (reader == null)
        {
            Logger.LogWithSubsystem("MunkiApps:GetPendingUpdatesList", "Reader is null", 1);
            return new List<string>();
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (!plist.ContainsKey("ItemsToInstall"))
        {
            Logger.LogWithSubsystem("MunkiApps:GetPendingUpdatesList", "ItemsToInstall key not found", 1);
            return new List<string>();
        }

        var pendingApps = (IList)plist["ItemsToInstall"];
        return pendingApps;
    }

    public async Task<IList> GetInstalledAppsList()
    {
        await LookForFileWithRetry(_managedInstallsReportPlist);
        await using var reader = await ReadFileWithRetry(_managedInstallsReportPlist);
        if (reader == null)
        {
            Logger.LogWithSubsystem("MunkiApps:GetInstalledAppsList", "Reader is null", 1);
            return new List<string>();
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (!plist.ContainsKey("ManagedInstalls"))
        {
            Logger.LogWithSubsystem("MunkiApps:GetInstalledAppsList", "ManagedInstalls key not found", 1);
            return new List<string>();
        }

        var installedApps = (IList)plist["ManagedInstalls"];
        return installedApps;
    }

    public async Task<IList> GetSelfServeAppsList()
    {
        await LookForFileWithRetry(_selfServeManifest);
        await using var reader = await ReadFileWithRetry(_selfServeManifest);
        if (reader == null)
        {
            Logger.LogWithSubsystem("MunkiApps:GetSelfServeAppsList", "Reader is null", 1);
            return new List<string>();
        }

        var plistReader = new PlistReader();
        var plist = plistReader.Read(reader);
        if (!plist.ContainsKey("managed_installs"))
        {
            Logger.LogWithSubsystem("MunkiApps:GetSelfServeAppsList", "managed_installs key not found", 1);
            return new List<string>();
        }

        var selfServeApps = (IList)plist["managed_installs"];
        return selfServeApps;
    }
}