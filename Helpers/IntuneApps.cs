using Microsoft.Data.Sqlite;
using Newtonsoft.Json.Linq;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.Helpers;

public class IntuneApps
{
    private readonly Dictionary<string, IntunePolicyModel.Policy> _intunePolicies = new();
    private readonly LoggerService _logger;
    private readonly string _sidecarDBPath = "/Library/Application Support/Microsoft/Intune/SideCar/sidecar.sqlite";
    private readonly string _sidecarQuery = "SELECT * FROM ZAPPSTATECHANGEITEM";

    // Default constructor
    public IntuneApps() : this(new LoggerService())
    {
    }

    // Constructor with LoggerService parameter
    private IntuneApps(LoggerService logger)
    {
        _logger = logger;
    }

    public async Task<Dictionary<string, IntunePolicyModel.Policy>> IntuneAppsDict()
    {
        if (!File.Exists(_sidecarDBPath))
        {
            _logger.Log("IntuneApps", "Intune database not found", 1);
            return _intunePolicies;
        }

        await using var connection = new SqliteConnection($"Data Source={_sidecarDBPath}");
        await connection.OpenAsync();
        await using var command = new SqliteCommand(_sidecarQuery, connection);
        await using var reader = await command.ExecuteReaderAsync();

        if (!reader.HasRows)
        {
            _logger.Log("IntuneApps", "No Intune apps found", 1);
            return _intunePolicies;
        }

        while (reader.Read())
        {
            var policyResultJson = reader["ZPOLICYRESULTJSON"]?.ToString();
            if (string.IsNullOrEmpty(policyResultJson)) continue;

            var policyResult = JObject.Parse(policyResultJson);
            var policy = new IntunePolicyModel.Policy
            {
                ApplicationName = policyResult["ApplicationName"]?.ToString(),
                ErrorDetails = policyResult["ErrorDetails"]?.ToString(),
                ErrorCode = (long?)policyResult["ErrorCode"] ?? 0,
                Intent = (int?)policyResult["Intent"] ?? 0,
                PolicyId = policyResult["PolicyId"]?.ToString(),
                PolicyType = (int?)policyResult["PolicyType"] ?? 0,
                PolicyVersion = (int?)policyResult["PolicyVersion"] ?? 0,
                ComplianceStateMessage = policyResult["ComplianceStateMessage"]
                    ?.ToObject<IntunePolicyModel.ComplianceStateMessage>(),
                EnforcementStateMessage = policyResult["EnforcementStateMessage"]
                    ?.ToObject<IntunePolicyModel.EnforcementStateMessage>()
            };

            if (!string.IsNullOrEmpty(policy.ApplicationName)) _intunePolicies[policy.ApplicationName] = policy;
        }

        await connection.CloseAsync();

        return _intunePolicies;
    }
}