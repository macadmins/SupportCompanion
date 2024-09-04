using Avalonia;
using Avalonia.Controls;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views
{
    public partial class HomeView : UserControl
    {
        public HomeView()
        {
            InitializeComponent();
            DataContext = new HomeViewModel();
        }

        protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
        {
            base.OnAttachedToVisualTree(e);

            var window = VisualRoot as Window;
            if (window != null)
            {
                window.Opened += Window_Opened;
                window.Closed += Window_Closed;
            }

            // Call a method to update or reload the data
            UpdateCustomWidgets();
        }

        protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
        {
            base.OnDetachedFromVisualTree(e);

            var window = VisualRoot as Window;
            if (window != null)
            {
                window.Opened -= Window_Opened;
                window.Closed -= Window_Closed;
            }
        }

        private void Window_Opened(object sender, EventArgs e)
        {
            if (App.Config.CustomWidgetsPath != string.Empty)
                UpdateCustomWidgets();
        }

        private void Window_Closed(object sender, EventArgs e)
        {
            // Clean up if necessary
            DataContext = null;
        }

        private void UpdateCustomWidgets()
        {
            if (DataContext is HomeViewModel viewModel)
            {
                // Call a method on the ViewModel to update or reload the custom widgets
                viewModel.LoadCustomWidgets(App.Config.CustomWidgetsPath);
            }
        }
    }
}