using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.Models;

public partial class MdmStatusModel : ObservableObject
{
    [ObservableProperty] private string _abm = string.Empty;
    [ObservableProperty] private string _enrolled = string.Empty;
    [ObservableProperty] private string _enrollmentDate = string.Empty;
}