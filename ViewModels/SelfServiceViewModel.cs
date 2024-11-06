using System.Collections.ObjectModel;
using Avalonia.Controls.Notifications;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.Input;
using ReactiveUI;
using SukiUI.Toasts;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class SelfServiceViewModel : ViewModelBase, IWindowStateAware
{
    private static readonly string defaultIcon = "ServiceToolbox";
    private readonly ActionsService _actionsService;
    private readonly LoggerService _logger;
    private ActionsModel? _actionsList;

    public SelfServiceViewModel(LoggerService loggerService, ActionsService actionsService,
        ISukiToastManager toastManager)
    {
        _logger = loggerService;
        _actionsService = actionsService;
        ToastManager = toastManager;
        ActionsList = new ActionsModel { ConfigActions = new ObservableCollection<ConfigAction>() };
        if (App.Config.Actions.Count > 0) Dispatcher.UIThread.Post(InitializeAsync);
    }

    public ISukiToastManager ToastManager { get; }

    public ActionsModel? ActionsList
    {
        get => _actionsList;
        set => this.RaiseAndSetIfChanged(ref _actionsList, value);
    }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        if (ActionsList?.ConfigActions == null || ActionsList.ConfigActions.Count == 0)
        {
            ActionsList = new ActionsModel { ConfigActions = new ObservableCollection<ConfigAction>() };
            Dispatcher.UIThread.Post(InitializeAsync);
        }
    }

    private async void InitializeAsync()
    {
        await GetActions();
    }

    private async Task GetActions()
    {
        // Clear the collection before fetching new actions
        ActionsList?.ConfigActions.Clear();

        foreach (var action in App.Config.Actions)
            if (action.Value.TryGetValue("Name", out var name) &&
                action.Value.TryGetValue("Command", out var command))
            {
                // get the icon if it exists
                action.Value.TryGetValue("Icon", out var icon);
                icon ??= defaultIcon;

                ActionsList.ConfigActions.Add(new ConfigAction
                {
                    Name = name,
                    Command = new RelayCommand(async () => await RunCommand(command)),
                    CommandString = command,
                    IsRunning = false,
                    Icon = icon
                });
            }
    }

    private async Task RunCommand(string command)
    {
        var action = ActionsList?.ConfigActions.FirstOrDefault(a => a.CommandString == command);
        if (action == null) return;

        try
        {
            action.IsRunning = true;
            await _actionsService.RunCommandWithoutOutput(command);
            //await SukiHost.ShowToast("Self Service", "Command executed successfully!");
            ToastManager.CreateSimpleInfoToast()
                .WithTitle("Self Service")
                .OfType(NotificationType.Success)
                .WithContent("Command executed successfully!")
                .Queue();
            action.IsRunning = false;
        }
        catch (Exception e)
        {
            action.IsRunning = false;
            _logger.Log("SelfServiceViewModel", e.Message, 3);
            //await SukiHost.ShowToast("Self Service", "Command failed to execute!");
            ToastManager.CreateSimpleInfoToast()
                .WithTitle("Self Service")
                .OfType(NotificationType.Error)
                .WithContent("Command failed to execute!")
                .Queue();
        }
    }

    private void CleanUp()
    {
        ActionsList?.ConfigActions.Clear();
        ActionsList = null;
    }
}