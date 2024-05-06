using System.Runtime.InteropServices;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace SupportCompanion.Helpers;

public class SystemInfo
{
    private readonly List<string> _ipAddresses = new();
    private string Result { get; set; } = string.Empty;

    [DllImport("libc", EntryPoint = "sysctlbyname")]
    internal static extern int sysctlbyname(
        [MarshalAs(UnmanagedType.LPStr)] string name,
        IntPtr output,
        IntPtr oldLen,
        IntPtr newp,
        uint newlen);

    public static string GetSystemInfo(string key)
    {
        var pLen = Marshal.AllocHGlobal(sizeof(int));
        sysctlbyname(key, IntPtr.Zero, pLen, IntPtr.Zero, 0);
        var length = Marshal.ReadInt32(pLen);
        var pStr = Marshal.AllocHGlobal(length);
        sysctlbyname(key, pStr, pLen, IntPtr.Zero, 0);
        return Marshal.PtrToStringAnsi(pStr);
    }

    public static long GetSystemInfoLong(string key)
    {
        var pLen = Marshal.AllocHGlobal(sizeof(int));
        sysctlbyname(key, IntPtr.Zero, pLen, IntPtr.Zero, 0);
        var length = Marshal.ReadInt32(pLen);
        var pInt = Marshal.AllocHGlobal(length);
        sysctlbyname(key, pInt, pLen, IntPtr.Zero, 0);
        return Marshal.ReadInt64(pInt);
    }

    public async Task<string> GetNetworkInfo(string dataType)
    {
        Result = await new StartProcess().RunCommand($"/usr/sbin/system_profiler {dataType} -json");
        // Parse the JSON output
        var networkInfo = JsonConvert.DeserializeObject<Dictionary<string, object>>(Result);
        // Get IPv4 addresses for each network interface if Addresses is not null
        foreach (var item in networkInfo)
            if (item.Key == $"{dataType}")
            {
                var networkData = (JArray)item.Value;
                foreach (var networkInterface in networkData)
                    // Check if IPv4 is present and if it contains Addresses
                    if (networkInterface["IPv4"] != null && networkInterface["IPv4"]["Addresses"] != null)
                    {
                        var ipAddresses = networkInterface["IPv4"]["Addresses"];
                        foreach (var ipAddress in ipAddresses) _ipAddresses.Add(ipAddress.ToString());
                    }
            }

        return string.Join(", ", _ipAddresses);
    }

    public async Task<int> GetLastBootTime()
    {
        Result = await new StartProcess().RunCommand("/usr/sbin/system_profiler -json SPSoftwareDataType");
        var softwareInfo = JsonConvert.DeserializeObject<Dictionary<string, object>>(Result);
        // get the uptime key from the JSON output
        var uptime = softwareInfo["SPSoftwareDataType"] as JArray;
        // get the uptime value from the JSON output
        var uptimeValue = uptime?[0]["uptime"];
        // convert the uptime value to a string
        var uptimeString = uptimeValue?.ToString();
        // split the uptime value into an array of strings
        var uptimeArray = uptimeString.Replace("up ", "").Split(":");
        if (uptimeArray.Length > 0)
            if (int.TryParse(uptimeArray[0], out var days))
                return days;
        return
            0; // Return 0 if the uptime string is not in the expected format or if the days part is not a valid integer
    }
}