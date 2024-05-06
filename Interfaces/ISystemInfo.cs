namespace SupportCompanion.Interfaces;

public interface ISystemInfo
{
    string GetHostName();
    string GetModel();
    string GetOSVersion();
    string GetOSBuild();
    string GetProcessor();
    long GetMemSize();
    Task<string> GetIPAddress();
    Task<int> GetLastBootTime();
}