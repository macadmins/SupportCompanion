using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.Interfaces;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views
{
    public partial class TransparentWindowFullView : UserControl
    {
        public TransparentWindowFullView()
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