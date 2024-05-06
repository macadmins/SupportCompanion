using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class MdmStatusService : IMdmStatus
{
    public async Task<Dictionary<string, string>> GetMdmStatus()
    {
        return await new MdmStatus().GetMdmStatus();
    }
}