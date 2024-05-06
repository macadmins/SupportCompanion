using CommunityToolkit.Mvvm.ComponentModel;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public partial class BatteryWidgetViewModel : ObservableObject
{
    private readonly IOKitService _iokit;
    [ObservableProperty] private int _BatteryCycleCount;
    private int _batteryDesignCapacity;
    [ObservableProperty] private int _BatteryHealth;
    [ObservableProperty] private string _BatteryHealthTextColor;
    private int _batteryMaxCapacity;

    public BatteryWidgetViewModel(IOKitService iokit)
    {
        _iokit = iokit;
        UpdateBatteryHealth();
    }

    private void UpdateBatteryInfo()
    {
        _batteryDesignCapacity = _iokit.GetBatteryDesignCapacity();
        _batteryMaxCapacity = _iokit.GetBatteryMaxCapacity();
        BatteryCycleCount = _iokit.GetBatteryCycleCount();
    }

    private void UpdateBatteryHealth()
    {
        UpdateBatteryInfo();
        BatteryHealth = (int)Math.Round((double)_batteryMaxCapacity / _batteryDesignCapacity * 100);
        BatteryHealthTextColor = BatteryHealth switch
        {
            < 30 => "#FF4F44",
            < 80 => "#FCE100",
            _ => "LightGreen"
        };
    }
}