using System.Runtime.InteropServices;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace SupportCompanion.Helpers;

public class SystemInfo : IDisposable
{
    private readonly List<string> _ipAddresses = new();
    private bool disposed;
    private string Result { get; set; } = string.Empty;

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    [DllImport("libc", EntryPoint = "sysctlbyname")]
    internal static extern int sysctlbyname(
        [MarshalAs(UnmanagedType.LPStr)] string name,
        IntPtr output,
        IntPtr oldLen,
        IntPtr newp,
        uint newlen);

    public static string GetSystemInfo(string key)
    {
        var pLen = IntPtr.Zero;
        var pStr = IntPtr.Zero;
        try
        {
            pLen = Marshal.AllocHGlobal(sizeof(int));
            sysctlbyname(key, IntPtr.Zero, pLen, IntPtr.Zero, 0);
            var length = Marshal.ReadInt32(pLen);
            pStr = Marshal.AllocHGlobal(length);
            sysctlbyname(key, pStr, pLen, IntPtr.Zero, 0);
            return Marshal.PtrToStringAnsi(pStr);
        }
        finally
        {
            if (pLen != IntPtr.Zero) Marshal.FreeHGlobal(pLen);
            if (pStr != IntPtr.Zero) Marshal.FreeHGlobal(pStr);
        }
    }

    public static long GetSystemInfoLong(string key)
    {
        var pLen = IntPtr.Zero;
        var pInt = IntPtr.Zero;
        try
        {
            pLen = Marshal.AllocHGlobal(sizeof(int));
            sysctlbyname(key, IntPtr.Zero, pLen, IntPtr.Zero, 0);
            var length = Marshal.ReadInt32(pLen);
            pInt = Marshal.AllocHGlobal(length);
            sysctlbyname(key, pInt, pLen, IntPtr.Zero, 0);
            return Marshal.ReadInt64(pInt);
        }
        finally
        {
            if (pLen != IntPtr.Zero) Marshal.FreeHGlobal(pLen);
            if (pInt != IntPtr.Zero) Marshal.FreeHGlobal(pInt);
        }
    }

    public async Task<string> GetNetworkInfo(string dataType)
    {
        Result = await new StartProcess().RunCommand($"/usr/sbin/system_profiler {dataType} -json");
        if (string.IsNullOrEmpty(Result)) return string.Empty;

        // Parse the JSON output
        var networkInfo = JsonConvert.DeserializeObject<Dictionary<string, object>>(Result);
        // Get IPv4 addresses for each network interface if Addresses is not null
        foreach (var item in networkInfo)
            if (item.Key == dataType)
            {
                var networkData = (JArray)item.Value;
                foreach (var networkInterface in networkData)
                {
                    // Check if IPv4 is present and if it contains Addresses
                    var ipv4 = networkInterface["IPv4"];
                    if (ipv4 != null && ipv4["Addresses"] != null)
                    {
                        var ipAddresses = ipv4["Addresses"];
                        foreach (var ipAddress in ipAddresses) _ipAddresses.Add(ipAddress.ToString());
                    }
                }
            }

        return string.Join(", ", _ipAddresses);
    }

    public async Task<int> GetLastBootTime()
    {
        Result = await new StartProcess().RunCommand("/usr/sbin/system_profiler -json SPSoftwareDataType");
        if (string.IsNullOrEmpty(Result)) return 0;

        var softwareInfo = JsonConvert.DeserializeObject<Dictionary<string, object>>(Result);
        // get the uptime key from the JSON output
        if (softwareInfo.TryGetValue("SPSoftwareDataType", out var uptimeData))
        {
            var uptime = uptimeData as JArray;
            // get the uptime value from the JSON output
            var uptimeValue = uptime?[0]?["uptime"];
            // convert the uptime value to a string
            var uptimeString = uptimeValue?.ToString();
            // split the uptime value into an array of strings
            if (!string.IsNullOrEmpty(uptimeString))
            {
                var uptimeArray = uptimeString.Replace("up ", "").Split(":");
                if (uptimeArray.Length > 0 && int.TryParse(uptimeArray[0], out var days)) return days;
            }
        }

        return
            0; // Return 0 if the uptime string is not in the expected format or if the days part is not a valid integer
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!disposed)
        {
            if (disposing)
                // Release any managed resources here.
                _ipAddresses.Clear();
            // Release unmanaged resources here.
            disposed = true;
        }
    }

    ~SystemInfo()
    {
        Dispose(false);
    }
}