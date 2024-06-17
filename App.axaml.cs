using System.Globalization;
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
using SupportCompanion.Views;

namespace SupportCompanion
{
    public partial class App : Application
    {
        public App()
        {
            RegisterAppServices();
        }

        public static AppConfiguration Config { get; private set; }
        public IServiceProvider ServiceProvider { get; private set; }

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

        private async Task InitializeCultureAsync()
        {
            var actionService = ServiceProvider.GetRequiredService<ActionsService>();
            var mainViewModel = ServiceProvider.GetRequiredService<MainWindowViewModel>();

            try
            {
                var locale = await actionService.RunCommandWithOutput("defaults read NSGlobalDomain AppleLocale");
                locale = locale?.Trim().Replace("_", "-");
                if (locale.Contains("@"))
                {
                    locale = locale.Split('@')[0];
                }

                if (!string.IsNullOrEmpty(locale))
                {
                    var cultureInfo = new CultureInfo(locale);
                    Assets.Resources.Culture = cultureInfo;
                }
                else
                {
                    Assets.Resources.Culture = CultureInfo.CurrentCulture;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to set culture: {ex.Message}");
                Assets.Resources.Culture = CultureInfo.CurrentCulture;
            }

            mainViewModel.NativeMenuOpenText = Assets.Resources.Open + " Support Companion";
            mainViewModel.NativeMenuSystemUpdatesText = Assets.Resources.NativeMenuSystemUpdates;
            mainViewModel.NativeMenuActionsHeader = Assets.Resources.Actions;
            mainViewModel.NativeMenuQuitAppText = Assets.Resources.Exit;
        }
        
        public override async void OnFrameworkInitializationCompleted()
        {
            RegisterAppServices();
            await InitializeCultureAsync();
            
            if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
            {
                desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;

                DataContext = ServiceProvider.GetRequiredService<MainWindowViewModel>();
                if (Config.IntuneMode)
                    Config.MunkiMode = false;
                var updateNotifications = ServiceProvider.GetRequiredService<UpdateNotifications>();

                // Register the URL handler
                var urlHandler = new UrlHandler(desktop);
                NSAppleEventManager.SharedAppleEventManager.SetEventHandler(urlHandler, 
                    new ObjCRuntime.Selector("handleGetURLEvent:withReplyEvent:"),
                    AEEventClass.Internet, AEEventID.GetUrl);

                if (App.Config.ShowDesktopInfo)
                {
                    var transparentWindow = new TransparentWindow();
                    transparentWindow.Show();
                }
            }
            
            if (Config.Actions != null && Config.Actions.Count > 0)
            {
                var mainViewModel = ServiceProvider.GetRequiredService<MainWindowViewModel>();
                // Create the main "Actions" menu item
                var actionsMenuItem = new NativeMenuItem { Header = mainViewModel.NativeMenuActionsHeader };
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
            serviceCollection.AddSingleton<TransparentWindowViewModel>();

            ServiceProvider = serviceCollection.BuildServiceProvider();
        }
    }
}
