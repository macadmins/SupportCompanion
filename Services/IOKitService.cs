using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class IOKitService : IIOKit
{
    public string GetProductName()
    {
        using var iokit = new IOKit();
        return iokit.GetProductName();
    }

    public string GetSerialNumber()
    {
        using var iokit = new IOKit();
        return iokit.GetSerialNumber();
    }

    public int GetBatteryDesignCapacity()
    {
        using var iokit = new IOKit();
        return iokit.GetBatteryDesignCapacity();
    }

    public int GetBatteryMaxCapacity()
    {
        using var iokit = new IOKit();
        return iokit.GetBatteryMaxCapacity();
    }

    public int GetBatteryCycleCount()
    {
        using var iokit = new IOKit();
        return iokit.GetBatteryCycleCount();
    }
}