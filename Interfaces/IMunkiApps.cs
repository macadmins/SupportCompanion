using System.Collections;

namespace SupportCompanion.Interfaces;

public interface IMunkiApps
{
    Task<int> PendingUpdates();
    Task<int> InstalledAppsCount();
    Task<IList> GetPendingUpdatesList();
    Task<IList> GetInstalledAppsList();
}