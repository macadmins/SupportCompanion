using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class IOKitService : IIOKit
{
    private readonly IOKit iokit = new();

    public string GetProductName()
    {
        return iokit.GetProductName();
    }

    public string GetSerialNumber()
    {
        return iokit.GetSerialNumber();
    }

    public int GetBatteryDesignCapacity()
    {
        return iokit.GetBatteryDesignCapacity();
    }

    public int GetBatteryMaxCapacity()
    {
        return iokit.GetBatteryMaxCapacity();
    }

    public int GetBatteryCycleCount()
    {
        return iokit.GetBatteryCycleCount();
    }

    public void Dispose()
    {
        iokit.Dispose();
    }
}