using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class MacPasswordService : IMacPassword
{
    public async Task<Dictionary<string, object>> GetKerberosSsoInfo()
    {
        return await new MacPassword().GetKerberosSSOinfo();
    }

    public async Task<Dictionary<string, object>> GetPlatformSsoInfo()
    {
        return await new MacPassword().GetPlatformSSOInfo();
    }
}