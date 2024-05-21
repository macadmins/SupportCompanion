using Avalonia.Controls;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class IdentityView : UserControl
{
    public IdentityView()
    {
        InitializeComponent();
        DataContext = new IdentityViewModel();
    }
}