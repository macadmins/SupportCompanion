using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class CatalogsService : ICatalogs
{
    public async Task<List<string>> GetCatalogs()
    {
        return await new Catalogs().GetCatalogs();
    }
}