using System.Collections;

namespace SupportCompanion.Interfaces;

public interface IStorage
{
    Task<IDictionary> GetStorageInfo();
    Task OpenStoragePanel();
}