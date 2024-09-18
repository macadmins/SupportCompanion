using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class IntuneUpdatesWidgetView : UserControl
{
    public IntuneUpdatesWidgetView()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        if (!App.Config.IntuneMode || App.Config.HiddenWidgets.Contains("IntuneUpdates")) return;

        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<IntuneUpdatesViewModel>();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        if (!App.Config.IntuneMode) return;

        base.OnDetachedFromVisualTree(e);
    }
}