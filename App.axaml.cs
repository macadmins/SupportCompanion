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

    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
        var prefs = new AppConfigHelper();
        prefs.SetPrefs();
        Config = AppConfigHelper.Config;
    }

    public override void OnFrameworkInitializationCompleted()
    {
        RegisterAppServices();

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            DataContext = ServiceProvider.GetRequiredService<MainWindowViewModel>();
            desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;
            if (Config.IntuneMode)
                Config.MunkiMode = false;
            var updateNotifications = ServiceProvider.GetRequiredService<UpdateNotifications>();
        }

        DataContext = ServiceProvider.GetRequiredService<MainWindowViewModel>();

        base.OnFrameworkInitializationCompleted();
    }

    private void RegisterAppServices()
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
        serviceCollection.AddSingleton<IntuneAppsService>();
        serviceCollection.AddSingleton<MacPasswordService>();
        serviceCollection.AddSingleton<UpdateNotifications>();
        serviceCollection.AddSingleton<LoggerService>();

        // Register view models
        serviceCollection.AddSingleton<DeviceWidgetViewModel>();
        serviceCollection.AddSingleton<MunkiPendingAppsViewModel>();
        serviceCollection.AddSingleton<MunkiUpdatesViewModel>();
        serviceCollection.AddSingleton<StorageViewModel>();
        serviceCollection.AddSingleton<MdmStatusViewModel>();
        serviceCollection.AddSingleton<EvergreenWidgetViewModel>();
        serviceCollection.AddSingleton<ActionsViewModel>();
        serviceCollection.AddSingleton<BatteryWidgetViewModel>();
        serviceCollection.AddSingleton<ApplicationsViewModel>();
        serviceCollection.AddSingleton<MainWindowViewModel>();
        serviceCollection.AddSingleton<SupportDialogViewModel>();
        serviceCollection.AddSingleton<IntuneUpdatesViewModel>();
        serviceCollection.AddSingleton<IntunePendingAppsViewModel>();
        serviceCollection.AddSingleton<UserViewModel>();
        serviceCollection.AddSingleton<MacPasswordViewModel>();

        ServiceProvider = serviceCollection.BuildServiceProvider();
    }
}