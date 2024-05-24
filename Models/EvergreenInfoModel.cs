using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class EvergreenInfoModel : ObservableObject
{
    [ObservableProperty] private ObservableCollection<string> _catalogs = new();
}