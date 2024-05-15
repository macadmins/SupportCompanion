using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;

namespace SupportCompanion.Services;

public class IntuneAppsService : IIntuneApps
{
    public async Task<Dictionary<string, IntunePolicyModel.Policy>> GetIntuneApps()
    {
        return await new IntuneApps().IntuneAppsDict();
    }
}