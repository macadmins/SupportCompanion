using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class ProfilerApplicationsModel : ObservableObject
{
    [ObservableProperty] private bool _arch;
    [ObservableProperty] private string _installedVersion = string.Empty;
    [ObservableProperty] private string _name = string.Empty;
}

public class InstalledAppProfiler
{
    public InstalledAppProfiler(string name, string version, string arch)
    {
        Name = name;
        Version = version;
        Arch = arch;
    }

    public string Name { get; set; }
    public string Version { get; set; }
    public string Arch { get; set; }
}