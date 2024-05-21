using CommunityToolkit.Mvvm.ComponentModel;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public partial class BatteryWidgetViewModel : ObservableObject, IDisposable
{
    private readonly IOKitService _iokit;
    [ObservableProperty] private int _batteryCycleCount;
    private int _batteryDesignCapacity;
    [ObservableProperty] private int _batteryHealth;
    [ObservableProperty] private string _batteryHealthTextColor;
    private int _batteryMaxCapacity;
    private bool _disposed;

    public BatteryWidgetViewModel(IOKitService iokit)
    {
        _iokit = iokit;
        UpdateBatteryHealth();
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
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
        _iokit.Dispose();
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();
            _disposed = true;
        }
    }

    ~BatteryWidgetViewModel()
    {
        Dispose(false);
    }
}