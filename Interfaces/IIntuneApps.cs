using SupportCompanion.Models;

namespace SupportCompanion.Interfaces;

public interface IIntuneApps
{
    Task<Dictionary<string, IntunePolicyModel.Policy>> GetIntuneApps();
}