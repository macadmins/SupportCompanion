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
        RegisterServices();

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
        serviceCollection.AddSingleton<IntuneAppsService>();
        serviceCollection.AddSingleton<MacPasswordService>();
        serviceCollection.AddSingleton<UpdateNotifications>();

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
        serviceCollection.AddTransient<IntuneUpdatesViewModel>();
        serviceCollection.AddTransient<IntunePendingAppsViewModel>();
        serviceCollection.AddTransient<UserViewModel>();
        serviceCollection.AddTransient<MacPasswordViewModel>();

        ServiceProvider = serviceCollection.BuildServiceProvider();
    }
}