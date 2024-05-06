using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using SukiUI.Controls;

namespace SupportCompanion.ViewModels;

public partial class SupportDialogViewModel : ObservableObject
{
    public SupportDialogViewModel()
    {
        SupportEmail = App.Config.SupportEmail;
        SupportPhone = App.Config.SupportPhone;
    }

    public string SupportEmail { get; set; }
    public string SupportPhone { get; set; }

    [RelayCommand]
    public void CloseDialog()
    {
        SukiHost.CloseDialog();
    }
}