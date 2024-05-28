using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using CommunityToolkit.Mvvm.Input;
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

    public App()
    {
        RegisterAppServices();
    }
    
    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
        var prefs = new AppConfigHelper();
        try
        {
            prefs.SetPrefs();
        }
        catch (Exception e)
        {
            var logger = ServiceProvider.GetRequiredService<LoggerService>();
            logger.Log("App initialization", "Error loading preferences: " + e.Message, 2);
        }
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

        if (Config.Actions != null && Config.Actions.Count > 0)
        {
            // Create the main "Actions" menu item
            var actionsMenuItem = new NativeMenuItem { Header = "Actions ✅" };
            actionsMenuItem.Menu = new NativeMenu();

            // Iterate over the Config.Actions and add them as sub-items
            foreach (var action in Config.Actions)
                if (action.Value.TryGetValue("Name", out var name) &&
                    action.Value.TryGetValue("Command", out var command))
                {
                    var subItem = new NativeMenuItem
                    {
                        Header = name,
                        Command = new RelayCommand(() =>
                        {
                            var actionsService = ServiceProvider.GetRequiredService<ActionsService>();
                            actionsService.RunCommandWithoutOutput(command);
                        })
                    };
                    actionsMenuItem.Menu.Items.Add(subItem);
                }

            // Insert the main "Actions" menu item at the third position (index 2)
            var trayIcon = TrayIcon.GetIcons(this).First();
            if (trayIcon.Menu.Items.Count > 2)
                trayIcon.Menu.Items.Insert(2, actionsMenuItem);
            else
                trayIcon.Menu.Items.Add(actionsMenuItem);
        }

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