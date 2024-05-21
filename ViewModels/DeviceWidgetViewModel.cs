using SukiUI.Controls;
using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class DeviceWidgetViewModel : ViewModelBase, IDisposable
{
    private readonly ClipboardService _clipboard;
    private readonly IOKitService _iioKit;
    private readonly SystemInfoService _systemInfo;
    private bool _disposed;

    public DeviceWidgetViewModel(IOKitService iioKit, SystemInfoService systemInfo,
        ClipboardService clipboard)
    {
        _iioKit = iioKit;
        _systemInfo = systemInfo;
        _clipboard = clipboard;
        DeviceInfo = new DeviceInfoModel();
        InitializeAsync();
    }

    public DeviceInfoModel? DeviceInfo { get; private set; }
    private string ModelValue { get; set; } = string.Empty;

    public string RebootToolTip =>
        "Regularly rebooting your device can enhance its performance and longevity\nby clearing temporary files and freeing up system resources.";

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    private async void InitializeAsync()
    {
        await GatherSystemInfo().ConfigureAwait(false);
    }

    private async Task GatherSystemInfo()
    {
        DeviceInfo.SerialNumber = _iioKit.GetSerialNumber();
        DeviceInfo.IpAddress = await _systemInfo.GetIPAddress();
        DeviceInfo.OsVersion = _systemInfo.GetOSVersion();
        DeviceInfo.OsBuild = _systemInfo.GetOSBuild();
        DeviceInfo.HostName = SystemInfo.GetSystemInfo("kern.hostname");
        ModelValue = _iioKit.GetProductName() ?? _systemInfo.GetModel();
        DeviceInfo.Model = ModelValue;
        DeviceInfo.Processor = _systemInfo.GetProcessor();
        DeviceInfo.MemSize = _systemInfo.GetMemSize();
        DeviceInfo.LastBootTime = await _systemInfo.GetLastBootTime();
        DeviceInfo.LastBootTimeColor = DeviceInfo.LastBootTime switch
        {
            < 7 => "LightGreen",
            < 14 => "#FCE100",
            _ => "#FF4F44"
        };
    }

    public async Task CopyToClipboard()
    {
        var systemInfo = $"Host Name: {DeviceInfo.HostName}\n" +
                         $"Serial Number: {DeviceInfo.SerialNumber}\n" +
                         $"Model: {DeviceInfo.Model}\n" +
                         $"Processor: {DeviceInfo.Processor}\n" +
                         $"Memory: {DeviceInfo.MemSize} GB\n" +
                         $"OS Version: {DeviceInfo.OsVersion}\n" +
                         $"OS Build: {DeviceInfo.OsBuild}\n" +
                         $"IP Address: {DeviceInfo.IpAddress}\n" +
                         $"Last Boot Time: {DeviceInfo.LastBootTime} days ago";

        try
        {
            await _clipboard.SetClipboardTextAsync(systemInfo);
            await SukiHost.ShowToast("Copy System Info", "System Info successfully copied", TimeSpan.FromSeconds(5));
        }
        catch (Exception e)
        {
            await SukiHost.ShowToast("Copy System Info", "Failed to copy System Info", TimeSpan.FromSeconds(5));
        }
    }

    private void CleanUp()
    {
        DeviceInfo = null;
        _iioKit.Dispose();
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();
            _disposed = true;
        }
    }

    ~DeviceWidgetViewModel()
    {
        Dispose(false);
    }
}