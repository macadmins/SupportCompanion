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
    private readonly Timer _timer;

    public DeviceWidgetViewModel(IOKitService iioKit, SystemInfoService systemInfo,
        ClipboardService clipboard)
    {
        _iioKit = iioKit;
        _systemInfo = systemInfo;
        _clipboard = clipboard;
        DeviceInfo = new DeviceInfoModel();
        Initialization = InitializeAsync();
        var interval = (int)TimeSpan.FromHours(24).TotalMilliseconds;
        _timer = new Timer(LastBootCallback, null, 0, interval);
    }

    public DeviceInfoModel DeviceInfo { get; }

    private string SerialNumberValue { get; set; } = string.Empty;
    private string IpValue { get; set; } = string.Empty;
    private string OSVersionValue { get; set; } = string.Empty;
    private string OSBuildValue { get; set; } = string.Empty;
    private string HostNameValue { get; set; } = string.Empty;
    private string ModelValue { get; set; } = string.Empty;
    private string ProcessorValue { get; set; } = string.Empty;
    private int LastBootTimeValue { get; set; }
    public Task Initialization { get; private set; }

    public string RebootToolTip =>
        "Regularly rebooting your device can enhance its performance and longevity\nby clearing temporary files and freeing up system resources.";

    public void Dispose()
    {
        _timer?.Dispose();
    }

    private async Task InitializeAsync()
    {
        await SerialNumber();
        await Ip();
        await OSversion();
        await OSBuild();
        await HostName();
        await Model();
        await Processor();
        await MemSize();
        await LastBootTime();
    }

    private async void LastBootCallback(object state)
    {
        await LastBootTime();
    }

    private async Task SerialNumber()
    {
        SerialNumberValue = _iioKit.GetSerialNumber();
        DeviceInfo.SerialNumber = SerialNumberValue;
    }

    private async Task Ip()
    {
        IpValue = await _systemInfo.GetIPAddress();
        DeviceInfo.IpAddress = IpValue;
    }

    private async Task OSversion()
    {
        OSVersionValue = _systemInfo.GetOSVersion();
        DeviceInfo.OsVersion = OSVersionValue;
    }

    private async Task OSBuild()
    {
        OSBuildValue = _systemInfo.GetOSBuild();
        DeviceInfo.OsBuild = OSBuildValue;
    }

    private async Task HostName()
    {
        HostNameValue = SystemInfo.GetSystemInfo("kern.hostname");
        DeviceInfo.HostName = HostNameValue;
    }

    private async Task Model()
    {
        var productName = _iioKit.GetProductName();
        ModelValue = productName ?? _systemInfo.GetModel();
        DeviceInfo.Model = ModelValue;
    }

    private async Task Processor()
    {
        ProcessorValue = _systemInfo.GetProcessor();
        DeviceInfo.Processor = ProcessorValue;
    }

    private async Task MemSize()
    {
        DeviceInfo.MemSize = _systemInfo.GetMemSize();
    }

    private async Task LastBootTime()
    {
        Logger.LogWithSubsystem("DeviceWidgetViewModel", "Getting Last Boot Time...", 1);
        LastBootTimeValue = await _systemInfo.GetLastBootTime();
        DeviceInfo.LastBootTime = LastBootTimeValue;

        DeviceInfo.LastBootTimeColor = LastBootTimeValue switch
        {
            < 7 => "LightGreen",
            < 14 => "#FCE100",
            _ => "#FF4F44"
        };
    }

    public async Task CopyToClipboard()
    {
        var systemInfo = $"Host Name: {HostNameValue}\n" +
                         $"Serial Number: {SerialNumberValue}\n" +
                         $"Model: {ModelValue}\n" +
                         $"Processor: {ProcessorValue}\n" +
                         $"Memory: {DeviceInfo.MemSize} GB\n" +
                         $"OS Version: {OSVersionValue}\n" +
                         $"OS Build: {OSBuildValue}\n" +
                         $"IP Address: {IpValue}\n" +
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
}