namespace SupportCompanion.Interfaces;

public interface ICatalogs
{
    Task<List<string>> GetCatalogs();
}