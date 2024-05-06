using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class SystemInfoService : ISystemInfo
{
    public string GetHostName()
    {
        return SystemInfo.GetSystemInfo("kern.hostname");
    }

    public string GetModel()
    {
        return SystemInfo.GetSystemInfo("hw.model");
    }

    public string GetOSVersion()
    {
        return SystemInfo.GetSystemInfo("kern.osproductversion");
    }

    public string GetOSBuild()
    {
        return SystemInfo.GetSystemInfo("kern.osversion");
    }

    public string GetProcessor()
    {
        return SystemInfo.GetSystemInfo("machdep.cpu.brand_string");
    }

    public long GetMemSize()
    {
        return SystemInfo.GetSystemInfoLong("hw.memsize_usable") / 1000 / 1000 / 1000;
    }

    public async Task<string> GetIPAddress()
    {
        return await new SystemInfo().GetNetworkInfo("SPNetworkDataType");
    }

    public async Task<int> GetLastBootTime()
    {
        return await new SystemInfo().GetLastBootTime();
    }
}