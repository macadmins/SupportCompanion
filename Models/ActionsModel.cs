using System.Windows.Input;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace SupportCompanion.Models;

public partial class ConfigAction : ObservableObject
{
    public string Name { get; set; }
    public RelayCommand Command { get; set; }
    public string CommandString { get; set; }
    [ObservableProperty] bool _isRunning;
}

public class ActionsModel
{
    public List<ConfigAction> ConfigActions { get; set; }
    
    public ActionsModel()
    {
        ConfigActions = new List<ConfigAction>();
    }
}