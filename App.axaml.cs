using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;
using SupportCompanion.ViewModels;

namespace SupportCompanion;

public class App : Application
{
    public static AppConfiguration Config { get; private set; }
    public IServiceProvider ServiceProvider { get; private set; }
    public ActionsViewModel ActionsViewModel { get; private set; }
    public MunkiPendingAppsViewModel MunkiPendingAppsViewModel { get; private set; }

    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
        var prefs = new AppConfigHelper();
        prefs.SetPrefs();
        Config = AppConfigHelper.Config;
    }

    public override void OnFrameworkInitializationCompleted()
    {
        RegisterServices();

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            // Check if the main window is null or closed
            /*if (desktop.MainWindow == null || (desktop.MainWindow as MainWindow)?.IsClosed == true)
                // If the main window is null or closed, create a new one
                desktop.MainWindow = new MainWindow
                {
                    DataContext = ServiceProvider.GetRequiredService<MainWindowViewModel>()
                };*/
            DataContext = ServiceProvider.GetRequiredService<MainWindowViewModel>();
            desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;
            if (!Config.HiddenActions.Contains("SoftwareUpdates"))
                ActionsViewModel = ServiceProvider.GetRequiredService<ActionsViewModel>();
            if (!Config.HiddenWidgets.Contains("MunkiPendingApps"))
                MunkiPendingAppsViewModel = ServiceProvider.GetRequiredService<MunkiPendingAppsViewModel>();
        }

        DataContext = ServiceProvider.GetRequiredService<MainWindowViewModel>();

        base.OnFrameworkInitializationCompleted();
    }

    private void RegisterServices()
    {
        var serviceCollection = new ServiceCollection();

        // Register your services
        serviceCollection.AddSingleton<IOKitService>();
        serviceCollection.AddSingleton<SystemInfoService>();
        serviceCollection.AddSingleton<MunkiAppsService>();
        serviceCollection.AddSingleton<StorageService>();
        serviceCollection.AddSingleton<MdmStatusService>();
        serviceCollection.AddSingleton<CatalogsService>();
        serviceCollection.AddSingleton<ActionsService>();
        serviceCollection.AddSingleton<ClipboardService>();
        serviceCollection.AddSingleton<NotificationService>();

        // Register view models
        serviceCollection.AddTransient<DeviceWidgetViewModel>();
        serviceCollection.AddTransient<MunkiPendingAppsViewModel>();
        serviceCollection.AddTransient<MunkiUpdatesViewModel>();
        serviceCollection.AddTransient<StorageViewModel>();
        serviceCollection.AddTransient<MdmStatusViewModel>();
        serviceCollection.AddTransient<EvergreenWidgetViewModel>();
        serviceCollection.AddTransient<ActionsViewModel>();
        serviceCollection.AddTransient<BatteryWidgetViewModel>();
        serviceCollection.AddTransient<ApplicationsViewModel>();
        serviceCollection.AddTransient<MainWindowViewModel>();
        serviceCollection.AddTransient<SupportDialogViewModel>();

        ServiceProvider = serviceCollection.BuildServiceProvider();
    }
}