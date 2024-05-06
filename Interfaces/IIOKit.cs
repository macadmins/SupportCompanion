namespace SupportCompanion.Interfaces;

public interface IIOKit
{
    string? GetProductName();
    string GetSerialNumber();
    int GetBatteryDesignCapacity();
    int GetBatteryMaxCapacity();
    int GetBatteryCycleCount();
}