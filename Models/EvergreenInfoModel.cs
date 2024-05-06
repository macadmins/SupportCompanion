using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class EvergreenInfoModel : ObservableObject
{
    [ObservableProperty] private List<string>? _catalogs = new();
}