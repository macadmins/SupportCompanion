using System.Collections;
using Newtonsoft.Json;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.Helpers;

public class ProfilerApplications
{
    private readonly LoggerService _logger;
    public IList InstalledApps { get; }
    
    public ProfilerApplications() : this(new LoggerService())
    {
    }
    
    private ProfilerApplications(LoggerService logger)
    {
        _logger = logger;
        InstalledApps = new List<object>();
    }
    
    public async Task<IList> GetInstalledApps()
    {
        var appsJson = string.Empty;
        _logger.Log("SystemProfilerApplications", "Getting installed applications", 1);
        try
        { 
            appsJson = await new StartProcess().RunCommand("system_profiler SPApplicationsDataType -json");
        }
        catch (Exception ex)
        {
            _logger.Log("SystemProfilerApplications", $"Error getting installed applications: {ex.Message}", 3);
        }
        var apps = JsonConvert.DeserializeObject<Dictionary<string, object>>(appsJson);
        var appsList = apps.TryGetValue("SPApplicationsDataType", out var appsListObj) ? appsListObj as IList : new List<object>();

        foreach (var app in appsList)
        {
            var appJObject = app as Newtonsoft.Json.Linq.JObject;
            var path = appJObject.TryGetValue("path", out var pathObj) ? pathObj.ToString() : string.Empty;
            var name = appJObject.TryGetValue("_name", out var nameObj) ? nameObj.ToString() : string.Empty;
            var version = appJObject.TryGetValue("version", out var versionObj) ? versionObj.ToString() : string.Empty;
            var arch = appJObject.TryGetValue("arch_kind", out var archObj) ? archObj.ToString() : string.Empty;
            if (!string.IsNullOrEmpty(path) && path.StartsWith("/Applications"))
            {
                InstalledApps.Add(new InstalledAppProfiler(
                    name,
                    version,
                    arch
                ));
            }
        }

        return InstalledApps;
    }
}