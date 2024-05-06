using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class IOKitService : IIOKit
{
    public string GetProductName()
    {
        return IOKit.GetProductName();
    }

    public string GetSerialNumber()
    {
        return IOKit.GetSerialNumber();
    }

    public int GetBatteryDesignCapacity()
    {
        return IOKit.GetBatteryDesignCapacity();
    }

    public int GetBatteryMaxCapacity()
    {
        return IOKit.GetBatteryMaxCapacity();
    }

    public int GetBatteryCycleCount()
    {
        return IOKit.GetBatteryCycleCount();
    }
}