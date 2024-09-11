using Avalonia.Threading;
using CommunityToolkit.Mvvm.Input;
using ReactiveUI;
using SukiUI.Controls;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class SelfServiceViewModel : ViewModelBase, IWindowStateAware
{
    private readonly LoggerService _logger;
    private readonly ActionsService _actionsService;
    private ActionsModel? _actionsList;
    public ActionsModel? ActionsList
    {
        get => _actionsList;
        set => this.RaiseAndSetIfChanged(ref _actionsList, value);
    }
    
    public SelfServiceViewModel(LoggerService loggerService, ActionsService actionsService)
    {
        _logger = loggerService;
        _actionsService = actionsService;
        ActionsList = new ActionsModel { ConfigActions = new List<ConfigAction>() };
        if (App.Config.Actions.Count > 0)
        {
            Dispatcher.UIThread.Post(InitializeAsync);
        }
    }
    
    private async void InitializeAsync()
    {
        await GetActions();
    }
    
    private async Task GetActions()
    {
        var actions = new List<ConfigAction>();
        foreach (var action in App.Config.Actions)
            if (action.Value.TryGetValue("Name", out var name) &&
                action.Value.TryGetValue("Command", out var command))
            {
                actions.Add(new ConfigAction
                {
                    Name = name,
                    Command = new RelayCommand(async () => await RunCommand(command)),
                    CommandString = command,
                    IsRunning = false
                });
            }
        ActionsList = new ActionsModel { ConfigActions = actions };
    }

    private async Task RunCommand(string command)
    {
        var action = ActionsList?.ConfigActions.FirstOrDefault(a => a.CommandString == command);
        if (action == null) return;
        
        try
        {
            action.IsRunning = true;
            await _actionsService.RunCommandWithoutOutput(command);
            await SukiHost.ShowToast("Self Service", "Command executed successfully!");
            action.IsRunning = false;
        }
        catch (Exception e)
        {
            action.IsRunning = false;
            _logger.Log("SelfServiceViewModel", e.Message, 3);
            await SukiHost.ShowToast("Self Service", "Command failed to execute!");
        }
    }
    public void OnWindowHidden()
    {
        CleanUp();
    }
    
    public void OnWindowShown()
    {
        ActionsList = new ActionsModel { ConfigActions = new List<ConfigAction>() };
        Dispatcher.UIThread.Post(InitializeAsync);
    }
    
    private void CleanUp()
    {
        ActionsList = null;
    }
}