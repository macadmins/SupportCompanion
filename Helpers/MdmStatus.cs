using Newtonsoft.Json;

namespace SupportCompanion.Helpers;

public class MdmStatus
{
    private readonly string _mdmStatusFile = Path.Combine("/usr/local", "supportcompanion", "mdm_status.json");

    public async Task<Dictionary<string, string>> GetMdmStatus()
    {
        if (!File.Exists(_mdmStatusFile))
        {
            Logger.LogWithSubsystem("MdmStatus", "MDM status file not found", 1);
            return new Dictionary<string, string>
            {
                { "ABM", "" },
                { "enrolled", "" },
                { "enrollmentDate", "" }
            };
        }

        var mdmStatus = await File.ReadAllTextAsync(_mdmStatusFile);
        var mdmStatusDict = JsonConvert.DeserializeObject<Dictionary<string, string>>(mdmStatus);
        return mdmStatusDict;
    }
}