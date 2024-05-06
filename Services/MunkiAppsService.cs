using System.Collections;
using SupportCompanion.Interfaces;
using MunkiApps = SupportCompanion.Helpers.MunkiApps;

namespace SupportCompanion.Services;

public class MunkiAppsService : IMunkiApps
{
    public async Task<int> PendingUpdates()
    {
        return await new MunkiApps().GetPendingUpdates();
    }

    public async Task<int> InstalledAppsCount()
    {
        return await new MunkiApps().GetInstalledAppsCount();
    }

    public async Task<IList> GetPendingUpdatesList()
    {
        return await new MunkiApps().GetPendingUpdatesList();
    }

    public async Task<IList> GetInstalledAppsList()
    {
        return await new MunkiApps().GetInstalledAppsList();
    }
}