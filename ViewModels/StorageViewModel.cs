using Avalonia.Threading;
using ReactiveUI;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class StorageViewModel : ViewModelBase, IWindowStateAware
{
    private readonly LoggerService _logger;
    private readonly StorageService _storage;
    public bool ShowData { get; private set; } = true;

    private StorageModel? _storageInfo;
    private Timer? _timer;

    public StorageViewModel(StorageService storage, LoggerService loggerService)
    {
        _storage = storage;
        _logger = loggerService;
        StorageInfo = new StorageModel();
        ShowManageStorageButton = Environment.OSVersion.Version.Major >= 13;
        if (!App.Config.HiddenWidgets.Contains("Storage"))
            Dispatcher.UIThread.Post(InitializeAsync);
        else
        {
            ShowData = false;
        }
    }

    public StorageModel? StorageInfo
    {
        get => _storageInfo;
        private set => this.RaiseAndSetIfChanged(ref _storageInfo, value);
    }

    public bool ShowManageStorageButton { get; private set; }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        StorageInfo = new StorageModel();
        if (!App.Config.HiddenWidgets.Contains("Storage"))
            Dispatcher.UIThread.Post(InitializeAsync);
    }

    private void StopTimer()
    {
        if (_timer == null) return;
        _logger.Log("StorageViewModel", "Stopping Storage timer", 1);
        _timer.Change(Timeout.Infinite, 0);
        _timer.Dispose();
        _timer = null;
    }

    private async void InitializeAsync()
    {
        _timer ??= new Timer(async _ => await StorageCallback(), null, TimeSpan.Zero, TimeSpan.FromMinutes(5));
    }

    private async Task StorageCallback()
    {
        await GetStorageInfo().ConfigureAwait(false);
    }

    private async Task GetStorageInfo()
    {
        try
        {
            _logger.Log("StorageViewModel", "Getting storage info...", 1);
            var storageInfo = await _storage.GetStorageInfo();
            StorageInfo.VolumeType = storageInfo["VolumeType"]?.ToString();
            StorageInfo.VolumeName = storageInfo["VolumeName"].ToString();
            StorageInfo.VolumeSize = Convert.ToDouble(storageInfo["VolumeSize"]);
            StorageInfo.VolumeUsed = Convert.ToDouble(storageInfo["VolumeUsed"]);
            StorageInfo.VolumeFree = Convert.ToDouble(storageInfo["VolumeFree"]);
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
        }
        catch (Exception ex)
        {
            _logger.Log("StorageViewModel", $"Error getting storage info: {ex.Message}", 3);
        }
    }

    public async Task OpenStoragePanel()
    {
        await _storage.OpenStoragePanel();
    }

    private void CleanUp()
    {
        StorageInfo = null;
        ShowManageStorageButton = false;
        StopTimer();
    }
}