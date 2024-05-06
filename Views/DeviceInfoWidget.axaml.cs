using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class DeviceInfoWidget : UserControl
{
    public DeviceInfoWidget()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<DeviceWidgetViewModel>();
    }
}