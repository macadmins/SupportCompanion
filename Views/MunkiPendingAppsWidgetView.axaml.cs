using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class MunkiPendingAppsWidgetView : UserControl
{
    public MunkiPendingAppsWidgetView()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        if (!App.Config.MunkiMode || App.Config.HiddenWidgets.Contains("MunkiPendingApps")) return;

        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<MunkiPendingAppsViewModel>();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        if (!App.Config.MunkiMode) return;

        base.OnDetachedFromVisualTree(e);
    }
}