namespace SupportCompanion.Interfaces;

public interface IMacPassword
{
    Task<Dictionary<string, object>> GetKerberosSsoInfo();
    Task<Dictionary<string, object>> GetPlatformSsoInfo();
}