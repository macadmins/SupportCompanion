using Newtonsoft.Json;
using SupportCompanion.Services;

namespace SupportCompanion.Helpers;

public class MdmStatus
{
    private readonly LoggerService _logger;

    private readonly string _mdmStatusFile =
        Path.Combine("/Library/Application Support/SupportCompanion/", "mdm_status.json");

    // Default constructor
    public MdmStatus() : this(new LoggerService())
    {
    }

    // Constructor with LoggerService parameter
    private MdmStatus(LoggerService logger)
    {
        _logger = logger;
    }

    public async Task<Dictionary<string, string>> GetMdmStatus()
    {
        if (!File.Exists(_mdmStatusFile))
        {
            _logger.Log("MdmStatus", "MDM status file not found", 1);
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