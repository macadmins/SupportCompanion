using System.Collections;
using PropertyList;
using SupportCompanion.Services;

namespace SupportCompanion.Helpers;

public class Catalogs
{
    private const string SerialNumberCommand =
        "/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}'";

    private readonly List<string> _catalogs = new();
    private readonly LoggerService _logger;
    private readonly string _manifestDirectory = "/Library/Managed Installs/manifests";

    // Default constructor
    public Catalogs() : this(new LoggerService())
    {
    }

    // Constructor with LoggerService parameter
    private Catalogs(LoggerService logger)
    {
        _logger = logger;
    }

    public async Task<List<string>> GetCatalogs()
    {
        var serialNumber = await new StartProcess().RunCommand(SerialNumberCommand);
        var deviceManifest = Path.GetFullPath(Path.Combine(_manifestDirectory, serialNumber));
        var siteDefaultManifest = Path.GetFullPath(Path.Combine(_manifestDirectory, "site_default"));
        if (File.Exists(deviceManifest))
            try
            {
                await using var reader = File.Open(deviceManifest, FileMode.Open, FileAccess.Read);
                var plistReader = new PlistReader();
                var plist = plistReader.Read(reader);
                if (plist.TryGetValue("catalogs", out var catalogs))
                    foreach (var catalog in (IList)catalogs)
                        _catalogs.Add(catalog.ToString());
                else
                    _logger.Log("Catalogs", "Device manifest does not contain catalogs key", 1);
            }
            catch (Exception e)
            {
                _logger.Log("Catalogs", $"Failed to read device manifest: {e.Message}", 2);
            }
        else
            _logger.Log("Catalogs", "Device manifest not found", 0);

        return _catalogs;
    }
}