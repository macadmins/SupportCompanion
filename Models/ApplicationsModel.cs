using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class ApplicationsModel : ObservableObject
{
    [ObservableProperty] private string _displayName = string.Empty;
    [ObservableProperty] private string _installedVersion = string.Empty;
    [ObservableProperty] private bool _isInstalled;
    [ObservableProperty] private string _versionToInstall = string.Empty;
}

public class InstalledApp
{
    public InstalledApp(string name, string version, string action, string arch, bool isSelfServe = false)
    {
        Name = name;
        Version = version;
        Action = action;
        Arch = arch;
        IsSelfServe = isSelfServe;
    }

    public string Name { get; set; }
    public string Version { get; set; }
    public string Action { get; set; }
    public string Arch { get; set; }
    public bool IsSelfServe { get; set; }
}