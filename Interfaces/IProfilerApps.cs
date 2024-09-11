using System.Collections;

namespace SupportCompanion.Interfaces;

public interface IProfilerApps
{
    Task<IList> GetInstalledApps();
}