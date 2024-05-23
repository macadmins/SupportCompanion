using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using CoreFoundation;
using Microsoft.Win32.SafeHandles;

namespace SupportCompanion.Helpers;

public class IOKit : IDisposable
{
    private const string kIOPlatformSerialNumberKey = "IOPlatformSerialNumber";
    private const string kIOProductNameKey = "product-name";
    private bool _disposed;

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern uint CFDataGetTypeID();

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern uint CFGetTypeID(IntPtr cf);

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern uint CFStringGetTypeID();

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern long CFDataGetLength(IntPtr theData);

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern IntPtr CFDataGetBytePtr(IntPtr theData);

    [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
    private static extern IntPtr IOServiceMatching(string name);

    [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
    private static extern IntPtr IORegistryEntryCreateCFProperty(uint device, IntPtr key, IntPtr allocator,
        uint options);

    [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
    private static extern uint IOServiceGetMatchingService(uint masterPort, IntPtr matching);

    [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
    private static extern int IOObjectRelease(uint device);

    [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
    private static extern IntPtr IOServiceNameMatching(string name);

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern bool CFNumberGetValue(IntPtr number, CFNumberType theType, out int valuePtr);

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern uint CFNumberGetTypeID();

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern SafeCFStringHandle CFStringCreateWithCharacters(IntPtr alloc, IntPtr chars, long numChars);

    [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
    private static extern void CFRelease(IntPtr cf);

    public string GetProductName()
    {
        return GetPropertyValue(kIOProductNameKey, "product");
    }

    public string GetSerialNumber()
    {
        return GetPropertyValue(kIOPlatformSerialNumberKey, "IOPlatformExpertDevice");
    }

    public int GetBatteryDesignCapacity()
    {
        return GetPropertyIntValue("DesignCapacity", "AppleSmartBattery");
    }

    public int GetBatteryMaxCapacity()
    {
        return GetPropertyIntValue("AppleRawMaxCapacity", "AppleSmartBattery");
    }

    public int GetBatteryCycleCount()
    {
        return GetPropertyIntValue("CycleCount", "AppleSmartBattery");
    }

    private string GetPropertyValue(string propertyName, string serviceName)
    {
        var result = string.Empty;
        var propertyPointer = IntPtr.Zero;

        var service = IOServiceGetMatchingService(0, IOServiceMatching(serviceName));
        if (service == 0)
            service = IOServiceGetMatchingService(0, IOServiceNameMatching(serviceName));

        if (service != 0)
            try
            {
                using (var key = CFStringCreateWithCharacters(IntPtr.Zero, Marshal.StringToHGlobalUni(propertyName),
                           propertyName.Length))
                {
                    if (key.IsInvalid)
                        throw new InvalidOperationException("Failed to create CFString key.");

                    propertyPointer =
                        IORegistryEntryCreateCFProperty(service, key.DangerousGetHandle(), IntPtr.Zero, 0);

                    if (propertyPointer != IntPtr.Zero)
                    {
                        var propertyType = CFGetTypeID(propertyPointer);
                        if (propertyType == CFStringGetTypeID())
                        {
                            result = CFString.FromHandle(propertyPointer);
                        }
                        else if (propertyType == CFDataGetTypeID())
                        {
                            var length = CFDataGetLength(propertyPointer);
                            var bytes = CFDataGetBytePtr(propertyPointer);
                            var buffer = new byte[length];
                            Marshal.Copy(bytes, buffer, 0, buffer.Length);
                            result = Encoding.UTF8.GetString(buffer);
                            result = Regex.Replace(result, @"[^\u0020-\u007E]", string.Empty, RegexOptions.Compiled);
                        }
                    }
                }
            }
            finally
            {
                if (propertyPointer != IntPtr.Zero)
                    CFRelease(propertyPointer);

                IOObjectRelease(service);
            }

        return result;
    }

    private int GetPropertyIntValue(string propertyName, string serviceName)
    {
        var result = 0;
        var propertyPointer = IntPtr.Zero;

        var service = IOServiceGetMatchingService(0, IOServiceNameMatching(serviceName));
        if (service != 0)
            try
            {
                using (var key = CFStringCreateWithCharacters(IntPtr.Zero, Marshal.StringToHGlobalUni(propertyName),
                           propertyName.Length))
                {
                    if (key.IsInvalid)
                        throw new InvalidOperationException("Failed to create CFString key.");

                    propertyPointer =
                        IORegistryEntryCreateCFProperty(service, key.DangerousGetHandle(), IntPtr.Zero, 0);

                    if (propertyPointer != IntPtr.Zero)
                    {
                        var propertyType = CFGetTypeID(propertyPointer);

                        if (propertyType == CFStringGetTypeID())
                        {
                            int.TryParse(CFString.FromHandle(propertyPointer), out result);
                        }
                        else if (propertyType == CFDataGetTypeID())
                        {
                            var length = CFDataGetLength(propertyPointer);
                            var bytes = CFDataGetBytePtr(propertyPointer);
                            var buffer = new byte[length];
                            Marshal.Copy(bytes, buffer, 0, buffer.Length);
                            if (length == 4) // int32
                            {
                                result = BitConverter.ToInt32(buffer, 0);
                            }
                            else if (length == 8) // int64
                            {
                                var longValue = BitConverter.ToInt64(buffer, 0);
                                result = (int)longValue;
                            }
                        }
                        else if (propertyType == CFNumberGetTypeID())
                        {
                            CFNumberGetValue(propertyPointer, CFNumberType.kCFNumberSInt32Type, out result);
                        }
                    }
                }
            }
            finally
            {
                if (propertyPointer != IntPtr.Zero)
                    CFRelease(propertyPointer);

                IOObjectRelease(service);
            }

        return result;
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing)
            {
                // Dispose managed resources
            }

            // Dispose unmanaged resources
            _disposed = true;
        }
    }

    ~IOKit()
    {
        Dispose(false);
    }

    private enum CFNumberType
    {
        kCFNumberSInt32Type = 3
    }

    private sealed class SafeCFStringHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeCFStringHandle() : base(true)
        {
        }

        public SafeCFStringHandle(IntPtr handle) : base(true)
        {
            SetHandle(handle);
        }

        protected override bool ReleaseHandle()
        {
            CFRelease(handle);
            return true;
        }

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern void CFRelease(IntPtr handle);
    }
}