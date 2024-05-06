using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class StorageModel : ObservableObject
{
    [ObservableProperty] private bool _fileVaultEnabled;
    [ObservableProperty] private bool _isEncrypted;
    [ObservableProperty] private string _isEncryptedColor = string.Empty;
    [ObservableProperty] private double _volumeFree;
    [ObservableProperty] private string _volumeName = string.Empty;
    [ObservableProperty] private double _volumeSize;
    [ObservableProperty] private string _volumeType = string.Empty;
    [ObservableProperty] private double _volumeUsed;
    [ObservableProperty] private double _volumeUsedPercentage;
    [ObservableProperty] private string _volumeUsedPercentageColor = string.Empty;
}