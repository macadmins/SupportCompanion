using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class KerberosSSOModel : ObservableObject
{
    [ObservableProperty] private string _expiryColor;
    [ObservableProperty] private bool _isKerberosSSO;
    [ObservableProperty] private int _kerberosPasswordExpiryDays;
    [ObservableProperty] private int _kerberosPasswordLastChangedDays;
    [ObservableProperty] private string _kerberosRealm;
    [ObservableProperty] private int _localPasswordLastChanged;
    [ObservableProperty] private string _userName;
}