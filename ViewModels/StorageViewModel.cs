using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class StorageViewModel : ViewModelBase, IDisposable
{
    private readonly StorageService _storage;
    private bool _disposed;
    private Timer? _timer;

    public StorageViewModel(StorageService storage)
    {
        _storage = storage;
        StorageInfo = new StorageModel();
        ShowManageStorageButton = Environment.OSVersion.Version.Major >= 13;
        _timer = new Timer(StorageCallback, null, 0, 300000);
    }

    public StorageModel? StorageInfo { get; private set; }
    public bool ShowManageStorageButton { get; private set; }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }
    
    public void StopTimer()
    {
        if (_timer != null)
        {
            _timer?.Change(Timeout.Infinite, 0);
            _timer?.Dispose();
            _timer = null;
        }
    }

    private async void StorageCallback(object? state)
    {
        await GetStorageInfo().ConfigureAwait(false);
    }

    private async Task GetStorageInfo()
    {
        try
        {
            Logger.LogWithSubsystem("StorageViewModel", "Getting storage info...", 1);
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
            Logger.LogWithSubsystem("StorageViewModel", $"Error getting storage info: {ex.Message}", 3);
        }
    }

    public async Task OpenStoragePanel()
    {
        await _storage.OpenStoragePanel();
    }

    private void CleanUp()
    {
        StorageInfo = null;
        StopTimer();
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();

            _disposed = true;
        }
    }

    ~StorageViewModel()
    {
        Dispose(false);
    }
}