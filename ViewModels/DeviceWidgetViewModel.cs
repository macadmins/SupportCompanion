using System.Net;
using Avalonia.Controls.Notifications;
using Avalonia.Threading;
using ReactiveUI;
using SukiUI.Toasts;
using SupportCompanion.Assets;
using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class DeviceWidgetViewModel : ViewModelBase, IWindowStateAware
{
    private readonly ClipboardService _clipboard;
    private readonly IOKitService _iioKit;
    private readonly SystemInfoService _systemInfo;
    private readonly ISukiToastManager _toastManager;
    private DeviceInfoModel? _deviceInfo;

    public DeviceWidgetViewModel(SystemInfoService systemInfo,
        ClipboardService clipboard, IOKitService iioKit, ISukiToastManager toastManager)
    {
        _iioKit = iioKit;
        _systemInfo = systemInfo;
        _clipboard = clipboard;
        ToastManager = toastManager;
        DeviceInfo = new DeviceInfoModel();
        Dispatcher.UIThread.Post(InitializeAsync);
    }

    public ISukiToastManager ToastManager { get; }

    public DeviceInfoModel? DeviceInfo
    {
        get => _deviceInfo;
        private set => this.RaiseAndSetIfChanged(ref _deviceInfo, value);
    }

    private string ModelValue { get; set; } = string.Empty;

    public string RebootToolTip => WebUtility.HtmlDecode(Resources.DeviceInfoLastRebootToolTip);

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        DeviceInfo = new DeviceInfoModel();
        Dispatcher.UIThread.Post(InitializeAsync);
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
            ToastManager.CreateSimpleInfoToast()
                .WithTitle("Copy System Info")
                .OfType(NotificationType.Success)
                .WithContent("System Info successfully copied")
                .Queue();
        }
        catch (Exception e)
        {
            ToastManager.CreateSimpleInfoToast()
                .WithTitle("Copy System Info")
                .OfType(NotificationType.Error)
                .WithContent("Failed to copy System Info")
                .Queue();
        }
    }

    private void CleanUp()
    {
        DeviceInfo = null;
        ModelValue = string.Empty;
    }
}