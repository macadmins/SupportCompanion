using System.Text.RegularExpressions;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class UserViewModel : ViewModelBase
{
    private const string LoginNamePattern = @"Login:\s+(\w+)";
    private const string NamePattern = @"Name:\s+(.+)";
    private const string HomeDirPattern = @"Directory:\s+(\S+)";
    private const string ShellPattern = @"Shell:\s+(\S+)";
    private readonly ActionsService _actionsService;

    public UserViewModel(ActionsService actionsService)
    {
        User = new UserModel();
        _actionsService = actionsService;
        InitializeAsync();
    }

    public UserModel User { get; }

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
}