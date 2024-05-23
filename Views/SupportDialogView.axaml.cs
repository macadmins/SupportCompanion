using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.Services;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class SupportDialogView : UserControl
{
    private readonly ClipboardService _clipboard;

    public SupportDialogView()
    {
        InitializeComponent();
        _clipboard = ((App)Application.Current).ServiceProvider.GetRequiredService<ClipboardService>();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<SupportDialogViewModel>();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
        DataContext = null;
    }
}