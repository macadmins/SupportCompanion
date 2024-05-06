using System.Collections;
using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class StorageService : IStorage
{
    public async Task<IDictionary> GetStorageInfo()
    {
        return await new Storage().GetStorageInfo();
    }

    public async Task OpenStoragePanel()
    {
        await new StartProcess().RunCommandWithoutOutput("open x-apple.systempreferences:com.apple.settings.Storage");
    }
}