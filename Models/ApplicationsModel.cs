using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class ApplicationsModel : ObservableObject
{
    [ObservableProperty] private string _displayName = string.Empty;
    [ObservableProperty] private string _installedVersion = string.Empty;
    [ObservableProperty] private bool _isInstalled;
    [ObservableProperty] private string _versionToInstall = string.Empty;
}