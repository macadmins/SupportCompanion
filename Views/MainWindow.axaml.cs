using Avalonia;
using Microsoft.Extensions.DependencyInjection;
using SukiUI.Controls;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class MainWindow : SukiWindow
{
    public MainWindow()
    {
        InitializeComponent();
    }

    public bool IsClosed { get; private set; }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<MainWindowViewModel>();
    }

    protected override void OnClosed(EventArgs e)
    {
        IsClosed = true;
        base.OnClosed(e);
    }
}