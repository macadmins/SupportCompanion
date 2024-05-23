using System.Runtime.InteropServices;

namespace SupportCompanion.Helpers;

public class Logger : IDisposable
{
    private const string DefaultSubsystem = "com.almenscorner.supportcompanion";
    private const string DylibName = "logger.dylib";
    private static IntPtr handle;
    private bool disposed;

    public Logger()
    {
        var dylibPath = NSBundle.MainBundle.BundlePath + "/Contents/MonoBundle/" + DylibName;
        handle = dlopen(dylibPath, 0);
        if (handle == IntPtr.Zero) throw new Exception("Unable to load dynamic library: " + dylibPath);
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    [DllImport(DylibName, CharSet = CharSet.Ansi)]
    private static extern void LogWithSubsystem(string subsystem, string category, string message, int severity);

    public void LogWithSubsystem(string category, string message, int severity)
    {
        LogWithSubsystem(DefaultSubsystem, category, message, severity);
    }

    [DllImport("libdl.dylib")]
    private static extern IntPtr dlopen(string filename, int flag);

    [DllImport("libdl.dylib")]
    private static extern int dlclose(IntPtr handle);

    protected virtual void Dispose(bool disposing)
    {
        if (!disposed)
        {
            if (handle != IntPtr.Zero)
            {
                dlclose(handle);
                handle = IntPtr.Zero;
            }

            disposed = true;
        }
    }

    ~Logger()
    {
        Dispose(false);
    }
}