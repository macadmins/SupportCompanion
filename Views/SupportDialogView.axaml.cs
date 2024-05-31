using System.Diagnostics;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Documents;
using Avalonia.Input;
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

    private void EmailLink_OnPointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (sender is TextBlock textBlock)
            // Find the Run element that contains the email address
            foreach (var inline in textBlock.Inlines)
                if (inline is Run run && run.Text.Contains("@"))
                {
                    var email = run.Text;
                    if (!string.IsNullOrEmpty(email))
                        Process.Start(new ProcessStartInfo("mailto:" + email) { UseShellExecute = true });
                    break;
                }
    }
}