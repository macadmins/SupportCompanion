using System.ComponentModel;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Threading;
using Avalonia.VisualTree;
using Microsoft.Extensions.DependencyInjection;
using SukiUI.Controls;
using SupportCompanion.Interfaces;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class MainWindow : SukiWindow
{
    private bool _isHiddenNotificationPending;
    private bool _isShownNotificationPending;
    private bool _isWindowCurrentlyVisible;

    public MainWindow()
    {
        InitializeComponent();
        Closing += OnClosing; // Subscribe to the Closing event
        this.GetObservable(IsVisibleProperty).Subscribe(OnIsVisibleChanged); // Subscribe to visibility changes
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        DataContext = ((App)Application.Current).ServiceProvider.GetRequiredService<MainWindowViewModel>();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
        Closing -= OnClosing; // Unsubscribe from the Closing event
    }

    private void OnClosing(object sender, CancelEventArgs e)
    {
        if (!UrlHandler.ActivatedViaUrl)
        {
            e.Cancel = true; // Cancel the close event
            Hide(); // Hide the window instead
            NotifyViewModelsWindowHidden(); // Notify view models that the window is hidden
        }
    }

    private void OnIsVisibleChanged(bool isVisible)
    {
        if (isVisible != _isWindowCurrentlyVisible)
        {
            _isWindowCurrentlyVisible = isVisible;
            if (isVisible)
            {
                if (!_isShownNotificationPending)
                {
                    _isShownNotificationPending = true;
                    Dispatcher.UIThread.Post(() =>
                    {
                        _isShownNotificationPending = false;
                        NotifyViewModelsWindowShown(); // Notify view models that the window is shown
                    });
                }
            }
            else
            {
                if (!_isHiddenNotificationPending)
                {
                    _isHiddenNotificationPending = true;
                    Dispatcher.UIThread.Post(() =>
                    {
                        _isHiddenNotificationPending = false;
                        NotifyViewModelsWindowHidden(); // Notify view models that the window is hidden
                    });
                }
            }
        }
    }

    private void NotifyViewModelsWindowHidden()
    {
        NotifyChildViewModels(this, false);
    }

    private void NotifyViewModelsWindowShown()
    {
        NotifyChildViewModels(this, true);
    }

    private void NotifyChildViewModels(Visual visual, bool isShown)
    {
        var notifiedContexts = new HashSet<object>();
        NotifyChildViewModelsRecursive(visual, isShown, notifiedContexts);
    }

    private void NotifyChildViewModelsRecursive(Visual visual, bool isShown, HashSet<object> notifiedContexts)
    {
        foreach (var child in visual.GetVisualChildren())
            if (child is Control control)
            {
                var dataContext = control.DataContext;
                if (dataContext is IWindowStateAware childViewModel)
                    if (!notifiedContexts.Contains(dataContext))
                    {
                        notifiedContexts.Add(dataContext);
                        if (isShown)
                            childViewModel.OnWindowShown();
                        else
                            childViewModel.OnWindowHidden();
                    }

                // Recursively notify child controls
                NotifyChildViewModelsRecursive(child, isShown, notifiedContexts);
            }
    }
}