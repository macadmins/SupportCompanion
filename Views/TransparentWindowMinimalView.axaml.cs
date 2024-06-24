using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views
{
    public partial class TransparentWindowMinimalView : UserControl
    {
        public TransparentWindowMinimalView()
        {
            InitializeComponent();
        }
        
        protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
        {
            base.OnAttachedToVisualTree(e);
            DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<TransparentWindowViewModel>();
        }
    }
}