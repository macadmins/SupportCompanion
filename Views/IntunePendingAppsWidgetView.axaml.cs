using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class IntunePendingAppsWidgetView : UserControl
{
    public IntunePendingAppsWidgetView()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        //if (!App.Config.IntuneMode) return;

        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<IntunePendingAppsViewModel>();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        if (!App.Config.IntuneMode) return;

        base.OnDetachedFromVisualTree(e);
    }
}