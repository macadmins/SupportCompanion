using System.Collections;
using PropertyList;

namespace SupportCompanion.Helpers;

public class Catalogs
{
    private const string SerialNumberCommand =
        "/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}'";

    private readonly List<string> _catalogs = new();
    private readonly string _manifestDirectory = "/Library/Managed Installs/manifests";

    public async Task<List<string>> GetCatalogs()
    {
        var serialNumber = await new StartProcess().RunCommand(SerialNumberCommand);
        var deviceManifest = Path.GetFullPath(Path.Combine(_manifestDirectory, serialNumber));
        var siteDefaultManifest = Path.GetFullPath(Path.Combine(_manifestDirectory, "site_default"));
        if (File.Exists(deviceManifest))
            try
            {
                using var reader = File.Open(deviceManifest, FileMode.Open, FileAccess.Read);
                var plistReader = new PlistReader();
                var plist = plistReader.Read(reader);
                if (!plist.ContainsKey("catalogs")) return _catalogs;
                var catalogs = (IList)plist["catalogs"];

                foreach (var catalog in catalogs) _catalogs.Add(catalog.ToString());
            }
            catch (Exception e)
            {
                Logger.LogWithSubsystem("Catalogs", $"Failed to read device manifest: {e.Message}", 2);
            }
        else
            Logger.LogWithSubsystem("Catalogs", "Device manifest not found", 0);

        return _catalogs;
    }
}