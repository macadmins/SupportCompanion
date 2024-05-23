using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class MunkiUpdatesWidgetView : UserControl
{
    public MunkiUpdatesWidgetView()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        if (!App.Config.MunkiMode) return;

        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<MunkiUpdatesViewModel>();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        if (!App.Config.MunkiMode) return;

        base.OnDetachedFromVisualTree(e);
    }
}