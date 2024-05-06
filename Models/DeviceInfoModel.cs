using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class DeviceInfoModel : ObservableObject
{
    [ObservableProperty] private string _hostName = string.Empty;
    [ObservableProperty] private string _ipAddress = string.Empty;
    [ObservableProperty] private int _lastBootTime;
    [ObservableProperty] private string _lastBootTimeColor = string.Empty;
    [ObservableProperty] private long _memSize;
    [ObservableProperty] private string _model = string.Empty;
    [ObservableProperty] private string _osBuild = string.Empty;
    [ObservableProperty] private string _osVersion = string.Empty;
    [ObservableProperty] private string _processor = string.Empty;
    [ObservableProperty] private string _serialNumber = string.Empty;
}