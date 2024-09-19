using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace SupportCompanion.Models;

public partial class ConfigAction : ObservableObject
{
    [ObservableProperty] private bool _isRunning;
    public string Name { get; set; }
    public RelayCommand Command { get; set; }
    public string CommandString { get; set; }
    public string Icon { get; set; }
}

public class ActionsModel
{
    public ActionsModel()
    {
        ConfigActions = new ObservableCollection<ConfigAction>();
    }

    public ObservableCollection<ConfigAction> ConfigActions { get; set; }
}