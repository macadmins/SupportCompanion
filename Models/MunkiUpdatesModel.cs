using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class MunkiUpdatesModel : ObservableObject
{
    [ObservableProperty] private int _installedApps;
    [ObservableProperty] private List<string> _installedAppsList = new();
    [ObservableProperty] private double _installPercentage;
    [ObservableProperty] private int _pendingUpdates;
    [ObservableProperty] private List<string> _pendingUpdatesList = new();
}

public class MunkiPendingApp
{
    public MunkiPendingApp(string name, string version)
    {
        Name = name;
        Version = version;
    }

    public string Name { get; set; }
    public string Version { get; set; }
}