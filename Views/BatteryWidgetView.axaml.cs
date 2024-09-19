using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class BatteryWidgetView : UserControl
{
    public BatteryWidgetView()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        if (App.Config.HiddenWidgets.Contains("Battery")) return;
        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<BatteryWidgetViewModel>();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
    }
}