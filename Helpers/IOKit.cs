using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using CoreFoundation;
using Microsoft.Win32.SafeHandles;

namespace SupportCompanion.Helpers;

public class IOKit
{
    private const string kIOPlatformSerialNumberKey = "IOPlatformSerialNumber";
    private const string kIOProductNameKey = "product-name";

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
    private static extern IntPtr
        IORegistryEntryCreateCFProperty(uint device, IntPtr key, IntPtr allocator, uint options);

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

    public static string GetProductName()
    {
        var productName = string.Empty;
        var product = IOServiceGetMatchingService(0, IOServiceNameMatching("product"));
        if (product != 0)
        {
            productName = GetPropertyStringValue(product, kIOProductNameKey);
            IOObjectRelease(product);
        }

        return productName;
    }

    public static string GetSerialNumber()
    {
        var serial = string.Empty;
        var platformExpert = IOServiceGetMatchingService(0, IOServiceMatching("IOPlatformExpertDevice"));
        if (platformExpert != 0)
        {
            serial = GetPropertyStringValue(platformExpert, kIOPlatformSerialNumberKey);
            IOObjectRelease(platformExpert);
        }

        return serial;
    }

    public static int GetBatteryDesignCapacity()
    {
        var designCapacity = 0;
        var battery = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"));
        if (battery != 0)
        {
            designCapacity = GetPropertyIntValue(battery, "DesignCapacity");
            IOObjectRelease(battery);
        }

        return designCapacity;
    }

    public static int GetBatteryMaxCapacity()
    {
        var maxCapacity = 0;
        var battery = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"));
        if (battery != 0)
        {
            maxCapacity = GetPropertyIntValue(battery, "AppleRawMaxCapacity");
            IOObjectRelease(battery);
        }

        return maxCapacity;
    }

    public static int GetBatteryCycleCount()
    {
        var cycleCount = 0;
        var battery = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"));
        if (battery != 0)
        {
            cycleCount = GetPropertyIntValue(battery, "CycleCount");
            IOObjectRelease(battery);
        }

        return cycleCount;
    }

    private static string GetPropertyStringValue(uint device, string propertyName)
    {
        var returnStr = string.Empty;

        var propertyPointer = IntPtr.Zero;
        try
        {
            using (var key = CFStringCreateWithCharacters(IntPtr.Zero, Marshal.StringToHGlobalUni(propertyName),
                       propertyName.Length))
            {
                if (key.IsInvalid)
                    throw new InvalidOperationException("Failed to create CFString key.");

                propertyPointer = IORegistryEntryCreateCFProperty(device, key.DangerousGetHandle(), IntPtr.Zero, 0);

                if (propertyPointer != IntPtr.Zero)
                {
                    var propertyType = CFGetTypeID(propertyPointer);
                    if (propertyType == CFStringGetTypeID())
                    {
                        returnStr = CFString.FromHandle(propertyPointer);
                    }
                    else if (propertyType == CFDataGetTypeID())
                    {
                        var length = CFDataGetLength(propertyPointer);
                        var bytes = CFDataGetBytePtr(propertyPointer);
                        var buffer = new byte[length];
                        Marshal.Copy(bytes, buffer, 0, buffer.Length);
                        returnStr = Encoding.UTF8.GetString(buffer);
                        // Remove non-printable characters
                        returnStr = Regex.Replace(returnStr, @"[^\u0020-\u007E]", string.Empty, RegexOptions.Compiled);
                    }
                }
            }
        }
        finally
        {
            if (propertyPointer != IntPtr.Zero) CFRelease(propertyPointer);
        }

        return returnStr;
    }

    private static int GetPropertyIntValue(uint device, string propertyName)
    {
        var returnInt = 0;

        try
        {
            using (var key = CFStringCreateWithCharacters(IntPtr.Zero, Marshal.StringToHGlobalUni(propertyName),
                       propertyName.Length))
            {
                if (key.IsInvalid)
                    throw new InvalidOperationException("Failed to create CFString key.");

                var propertyPointer = IORegistryEntryCreateCFProperty(device, key.DangerousGetHandle(), IntPtr.Zero, 0);
                if (propertyPointer != IntPtr.Zero)
                    try
                    {
                        var propertyType = CFGetTypeID(propertyPointer);

                        if (propertyType == CFStringGetTypeID())
                        {
                            int.TryParse(CFString.FromHandle(propertyPointer), out returnInt);
                        }
                        else if (propertyType == CFDataGetTypeID())
                        {
                            var length = CFDataGetLength(propertyPointer);
                            var bytes = CFDataGetBytePtr(propertyPointer);
                            var buffer = new byte[length];
                            Marshal.Copy(bytes, buffer, 0, buffer.Length);
                            if (length == 4) // int32
                            {
                                returnInt = BitConverter.ToInt32(buffer, 0);
                            }
                            else if (length == 8) // int64
                            {
                                var longValue = BitConverter.ToInt64(buffer, 0);
                                returnInt = (int)longValue;
                            }
                        }
                        else if (propertyType == CFNumberGetTypeID())
                        {
                            CFNumberGetValue(propertyPointer, CFNumberType.kCFNumberSInt32Type, out returnInt);
                        }
                    }
                    finally
                    {
                        CFRelease(propertyPointer);
                    }
                else
                    Logger.LogWithSubsystem("IOKit", $"Property Pointer for {propertyName} is zero", 1);
            }
        }
        catch (Exception ex)
        {
            Logger.LogWithSubsystem("IOKit", $"Exception in GetPropertyIntValue: {ex.Message}", 1);
        }

        return returnInt;
    }

    private enum CFNumberType
    {
        kCFNumberSInt32Type = 3
    }

    private sealed class SafeCFStringHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        // Default constructor for P/Invoke
        private SafeCFStringHandle() : base(true)
        {
        }

        // Constructor to wrap an existing IntPtr
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