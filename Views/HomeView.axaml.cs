using Avalonia.Controls;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class HomeView : UserControl
{
    public HomeView()
    {
        InitializeComponent();
        DataContext = new HomeViewModel();
    }
}