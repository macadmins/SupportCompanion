using Avalonia;
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

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);

        var window = VisualRoot as Window;
        if (window != null) window.Closed -= Window_Closed;
    }

    private void Window_Closed(object sender, EventArgs e)
    {
        DataContext = null;
        var window = sender as Window;
        if (window != null) window.Closed -= Window_Closed;
    }
}