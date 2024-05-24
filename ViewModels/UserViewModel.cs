using System.Text.RegularExpressions;
using Avalonia.Threading;
using ReactiveUI;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class UserViewModel : ViewModelBase, IWindowStateAware
{
    private const string HomeDirPattern = @"Directory:\s+(\S+)";
    private const string LoginNamePattern = @"Login:\s+(\w+)";
    private const string NamePattern = @"Name:\s+(.+)";
    private const string ShellPattern = @"Shell:\s+(\S+)";
    private readonly ActionsService _actionsService;

    private UserModel _user;

    public UserViewModel(ActionsService actionsService)
    {
        User = new UserModel();
        _actionsService = actionsService;
        Dispatcher.UIThread.Post(InitializeAsync);
    }

    public UserModel? User
    {
        get => _user;
        private set => this.RaiseAndSetIfChanged(ref _user, value);
    }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        User = new UserModel();
        Dispatcher.UIThread.Post(InitializeAsync);
    }

    private async void InitializeAsync()
    {
        await GetUserInfo().ConfigureAwait(false);
    }

    private async Task GetUserInfo()
    {
        var userOutput = await _actionsService.RunCommandWithOutput("finger $USER");
        // Get user info
        User.Login = Regex.Match(userOutput, LoginNamePattern).Groups[1].Value;
        User.Name = Regex.Match(userOutput, NamePattern).Groups[1].Value;
        User.HomeDir = Regex.Match(userOutput, HomeDirPattern).Groups[1].Value;
        User.Shell = Regex.Match(userOutput, ShellPattern).Groups[1].Value;
    }

    private void CleanUp()
    {
        User = null;
    }
}