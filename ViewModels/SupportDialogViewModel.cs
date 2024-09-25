using CommunityToolkit.Mvvm.ComponentModel;

namespace SupportCompanion.ViewModels;

public class SupportDialogViewModel : ObservableObject
{
    public SupportDialogViewModel()
    {
        SupportEmail = App.Config.SupportEmail;
        SupportPhone = App.Config.SupportPhone;
    }

    public string SupportEmail { get; set; }
    public string SupportPhone { get; set; }
}