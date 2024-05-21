namespace SupportCompanion.Models;

public class IntunePolicyModel
{
    public class ComplianceStateMessage
    {
        public int Applicability { get; set; }
        public int ComplianceState { get; set; }
        public int DesiredState { get; set; }
        public long ErrorCode { get; set; }
        public int InstallContext { get; set; }
        public string ProductVersion { get; set; }
        public int TargetType { get; set; }
    }

    public class EnforcementStateMessage
    {
        public int EnforcementState { get; set; }
        public long ErrorCode { get; set; }
    }

    public class Policy
    {
        public string ApplicationName { get; set; }
        public string ErrorDetails { get; set; }
        public long ErrorCode { get; set; }
        public int Intent { get; set; }
        public string PolicyId { get; set; }
        public int PolicyType { get; set; }
        public int PolicyVersion { get; set; }
        public ComplianceStateMessage ComplianceStateMessage { get; set; }
        public EnforcementStateMessage EnforcementStateMessage { get; set; }
    }
}

public class IntunePendingApp
{
    public string Name { get; set; }
    public string PendingReason { get; set; }
    public bool ShowInfoIcon { get; set; }
}