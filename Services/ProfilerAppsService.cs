using System.Collections;
using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;

namespace SupportCompanion.Services;

public class ProfilerAppsService : IProfilerApps
{   
    public async Task<IList> GetInstalledApps()
    {
        return await new ProfilerApplications().GetInstalledApps();
    }
}