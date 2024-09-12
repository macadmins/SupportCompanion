using Avalonia.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using SupportCompanion.Interfaces;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public partial class BatteryWidgetViewModel : ObservableObject, IWindowStateAware
{
    private readonly IOKitService _iokit;
    [ObservableProperty] private int _batteryCycleCount;
    private int _batteryDesignCapacity;
    [ObservableProperty] private int _batteryHealth;
    [ObservableProperty] private string _batteryHealthTextColor;
    private int _batteryMaxCapacity;
    public BatteryWidgetViewModel(IOKitService iokit)
    {
        _iokit = iokit;
        Dispatcher.UIThread.Post(Initialize);
    }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        Dispatcher.UIThread.Post(Initialize);
    }

    private void Initialize()
    {
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

    private void CleanUp()
    {
        // Reset the fields to default values
        _batteryDesignCapacity = 0;
        _batteryMaxCapacity = 0;
        BatteryCycleCount = 0;
        BatteryHealth = 0;
        BatteryHealthTextColor = string.Empty;
    }
}