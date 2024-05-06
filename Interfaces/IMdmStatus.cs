namespace SupportCompanion.Interfaces;

public interface IMdmStatus
{
    Task<Dictionary<string, string>> GetMdmStatus();
}