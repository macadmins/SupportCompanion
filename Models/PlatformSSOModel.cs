using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class PlatformSSOModel : ObservableObject
{
    [ObservableProperty] private string _extensionIdentifier;
    [ObservableProperty] private bool _isPlatformSSO;
    [ObservableProperty] private int _loginFrequency;
    [ObservableProperty] private string _loginType;
    [ObservableProperty] private string _newUserAuthorizationMode;
    [ObservableProperty] private bool _registrationCompleted;
    [ObservableProperty] private string _registrationStatusColor;
    [ObservableProperty] private decimal _sdkVersionString;
    [ObservableProperty] private bool _sharedDeviceKeys;
    [ObservableProperty] private string _userAuthorizationMode;
}