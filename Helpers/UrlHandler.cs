using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Threading;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.ViewModels;
using SupportCompanion.Views;

namespace SupportCompanion;

public class UrlHandler : NSObject
{
    // Define the AEKeywordDirectObject manually
    private const uint AEKeywordDirectObject = 0x2D2D2D2D;
    private readonly IClassicDesktopStyleApplicationLifetime _desktop;

    public UrlHandler(IClassicDesktopStyleApplicationLifetime desktop)
    {
        _desktop = desktop;
    }

    public static bool ActivatedViaUrl { get; private set; }

    [Export("handleGetURLEvent:withReplyEvent:")]
    public void HandleGetURLEvent(NSAppleEventDescriptor descriptor, NSAppleEventDescriptor replyEvent)
    {
        var paramDescriptor = descriptor.ParamDescriptorForKeyword(AEKeywordDirectObject);
        if (paramDescriptor != null)
        {
            var url = paramDescriptor.StringValue;
            if (url != null) Dispatcher.UIThread.Post(() => HandleUri(url));
        }
    }

    private void HandleUri(string uri)
    {
        if (uri == "supportcompanion://home")
            if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktopApp)
            {
                ActivatedViaUrl = true;
                desktopApp.ShutdownMode = ShutdownMode.OnMainWindowClose;
                var mainWindowViewModel =
                    ((App)Application.Current).ServiceProvider.GetRequiredService<MainWindowViewModel>();
                desktopApp.MainWindow = new MainWindow { DataContext = mainWindowViewModel };
                desktopApp.MainWindow.Show();
            }
    }
}