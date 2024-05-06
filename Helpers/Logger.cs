using System.Runtime.InteropServices;

namespace SupportCompanion.Helpers;

public static class Logger
{
    private const string DefaultSubsystem = "com.almenscorner.supportcompanion";
    private const string DylibName = "logger.dylib";

    static Logger()
    {
        var dylibPath = NSBundle.MainBundle.BundlePath + "/Contents/MonoBundle/" + DylibName;
        var handle = dlopen(dylibPath, 0);
        if (handle == IntPtr.Zero) throw new Exception("Unable to load dynamic library: " + dylibPath);
    }

    [DllImport(DylibName, CharSet = CharSet.Ansi)]
    private static extern void LogWithSubsystem(string subsystem, string category, string message, int severity);

    public static void LogWithSubsystem(string category, string message, int severity)
    {
        LogWithSubsystem(DefaultSubsystem, category, message, severity);
    }

    [DllImport("libdl.dylib")]
    private static extern IntPtr dlopen(string filename, int flag);
}