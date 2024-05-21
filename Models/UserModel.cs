using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class UserModel : ObservableObject
{
    [ObservableProperty] private string _homeDir;
    [ObservableProperty] private string _login;
    [ObservableProperty] private string _name;
    [ObservableProperty] private string _shell;
}