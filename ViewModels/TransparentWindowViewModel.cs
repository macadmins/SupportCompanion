using Avalonia.Threading;
using ReactiveUI;
using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class TransparentWindowViewModel : ViewModelBase
{
    private IOKitService _iioKit;
    private SystemInfoService _systemInfo;
    private readonly StorageService _storage;
    private Timer? _timer;
    private StorageModel? _storageInfo;
    private DeviceInfoModel? _deviceInfo;
    private string ModelValue { get; set; } = string.Empty;
    public ITransparentWindow TransparentWindow { get; set; }
    public static string SupportPhoneNumber => App.Config.SupportPhone;
    public static string SupportEmail => App.Config.SupportEmail;
    public static int FontSize => App.Config.FontSize;
    public bool ShowSupportInfo { get; private set; }
    public string HorizontalAlignment { get; private set; }
    public string VerticalAlignment { get; private set; }
    
    public TransparentWindowViewModel(IOKitService iioKit, SystemInfoService systemInfo, StorageService storage)
    {
        ShowSupportInfo = true;
        _iioKit = iioKit;
        _systemInfo = systemInfo;
        _storage = storage;
        DeviceInfo = new DeviceInfoModel();
        StorageInfo = new StorageModel();
        Dispatcher.UIThread.InvokeAsync(async () => await InitializeAsync());
        if (App.Config.DesktopInfoLevel == "Device")
            ShowSupportInfo = false;
        VerticalAlignment = App.Config.DesktopPosition.Contains("Bottom") ? "Bottom" : "Top";
        HorizontalAlignment = App.Config.DesktopPosition.Contains("Right") ? "Right" : "Left";
    }
    
    public DeviceInfoModel? DeviceInfo
    {
        get => _deviceInfo;
        private set => this.RaiseAndSetIfChanged(ref _deviceInfo, value);
    }
    
    public StorageModel? StorageInfo
    {
        get => _storageInfo;
        private set => this.RaiseAndSetIfChanged(ref _storageInfo, value);
    }
   
    private async void GatherSystemInfoSafe()
    {
        try
        {
            await GatherSystemInfo();
        }
        catch (Exception e)
        {
            Console.WriteLine(e);
        }
    }
    private async Task InitializeAsync()
    {
        var interval = (int)TimeSpan.FromSeconds(30).TotalMilliseconds;
        _timer ??= new Timer(_ => GatherSystemInfoSafe(), null, 0, interval);
    }
    
    private async Task GatherSystemInfo()
    {
        Dispatcher.UIThread.InvokeAsync( async () =>
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

            var storageInfo = await _storage.GetStorageInfo();
            StorageInfo.VolumeName = storageInfo["VolumeName"].ToString();
            StorageInfo.VolumeUsedPercentage = Convert.ToDouble(storageInfo["VolumeUsedPercentage"]);
            StorageInfo.IsEncrypted = Convert.ToBoolean(storageInfo["IsEncrypted"]);
            StorageInfo.FileVaultEnabled = Convert.ToBoolean(storageInfo["FileVaultEnabled"]);
            StorageInfo.IsEncryptedColor = StorageInfo.FileVaultEnabled ? "LightGreen" : "#FF4F44";
            StorageInfo.VolumeUsedPercentageColor = StorageInfo.VolumeUsedPercentage switch
            {
                < 65 => "LightGreen",
                < 80 => "#FCE100",
                _ => "#FF4F44"
            };
            
            TransparentWindow.hide();
            TransparentWindow.show();
        });
    }
}