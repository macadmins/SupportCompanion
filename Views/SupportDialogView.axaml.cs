using Avalonia;
using Avalonia.Controls;
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


    public async void OnKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.C && e.KeyModifiers == KeyModifiers.Meta)
        {
            var textBlock = (SelectableTextBlock)sender;
            var selectedText = textBlock.SelectedText;

            if (!string.IsNullOrEmpty(selectedText)) await _clipboard.SetClipboardTextAsync(selectedText);
        }
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<SupportDialogViewModel>();
    }
}