using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class StorageViewModel : ViewModelBase, IDisposable
{
    private readonly StorageService _storage;
    private readonly Timer _timer;

    public StorageViewModel(StorageService storage)
    {
        _storage = storage;
        StorageInfo = new StorageModel();
        ShowManageStorageButton = Environment.OSVersion.Version.Major >= 13;
        InitializeAsync();
        _timer = new Timer(StorageCallback, null, 0, 300000);
    }

    public StorageModel StorageInfo { get; }
    public bool ShowManageStorageButton { get; private set; }

    public void Dispose()
    {
        _timer.Dispose();
    }

    private async void StorageCallback(object state)
    {
        await GetStorageInfo();
    }

    private async void InitializeAsync()
    {
        await GetStorageInfo();
    }

    private async Task GetStorageInfo()
    {
        Logger.LogWithSubsystem("StorageViewModel", "Getting storage info...", 1);
        var storageInfo = await _storage.GetStorageInfo();
        StorageInfo.VolumeType = storageInfo["VolumeType"].ToString();
        StorageInfo.VolumeName = storageInfo["VolumeName"].ToString();
        StorageInfo.VolumeSize = Convert.ToDouble(storageInfo["VolumeSize"]);
        StorageInfo.VolumeUsed = Convert.ToDouble(storageInfo["VolumeUsed"]);
        StorageInfo.VolumeFree = Convert.ToDouble(storageInfo["VolumeFree"]);
        StorageInfo.VolumeUsedPercentage = Convert.ToDouble(storageInfo["VolumeUsedPercentage"]);
        StorageInfo.IsEncrypted = Convert.ToBoolean(storageInfo["IsEncrypted"]);
        StorageInfo.FileVaultEnabled = Convert.ToBoolean(storageInfo["FileVaultEnabled"]);

        if (StorageInfo.IsEncrypted == false)
            StorageInfo.IsEncryptedColor = "#FF4F44";
        else
            StorageInfo.IsEncryptedColor = "LightGreen";

        StorageInfo.VolumeUsedPercentageColor = StorageInfo.VolumeUsedPercentage switch
        {
            < 65 => "LightGreen",
            < 80 => "#FCE100",
            _ => "#FF4F44"
        };
    }

    public async Task OpenStoragePanel()
    {
        await _storage.OpenStoragePanel();
    }
}