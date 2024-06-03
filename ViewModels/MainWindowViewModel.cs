using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Media.Imaging;
using Avalonia.Styling;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.Services;
using SupportCompanion.Views;

namespace SupportCompanion.ViewModels;

public partial class MainWindowViewModel : ObservableObject
{
    private readonly ActionsService _actionsService;
    [ObservableProperty] private string _nativeMenuActionsHeader;

    [ObservableProperty] private string _nativeMenuOpenText;
    [ObservableProperty] private string _nativeMenuQuitAppText;
    [ObservableProperty] private string _nativeMenuSystemUpdatesText;

    public MainWindowViewModel(ActionsService actionsService)

    {
        ShowHeader = !string.IsNullOrEmpty(App.Config.BrandName);
        BrandName = App.Config.BrandName;
        if (File.Exists(App.Config.BrandLogo))
        {
            BrandLogo = new Bitmap(App.Config.BrandLogo);
            ShowLogo = true;
            ShowMenuToggle = App.Config.ShowMenuToggle;
        }

        _actionsService = actionsService;
    }

    public bool ShowHeader { get; private set; }
    public bool ShowLogo { get; private set; }
    public string BrandName { get; private set; }
    public Bitmap BrandLogo { get; private set; }
    public bool ShowMenuToggle { get; private set; }

    [RelayCommand]
    private void ToggleBaseTheme()
    {
        if (Application.Current is null) return;
        var newBase = Application.Current.ActualThemeVariant == ThemeVariant.Dark
            ? ThemeVariant.Light
            : ThemeVariant.Dark;
        Application.Current.RequestedThemeVariant = newBase;
    }

    [RelayCommand]
    public async Task OpenSystemUpdates()
    {
        if (Environment.OSVersion.Version.Major >= 13)
            await _actionsService.RunCommandWithoutOutput(
                "open x-apple.systempreferences:com.apple.preferences.softwareupdate");
        else
            await _actionsService.RunCommandWithoutOutput(
                "open /System/Library/PreferencePanes/SoftwareUpdate.prefPane");
    }

    [RelayCommand]
    public void QuitApp()
    {
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktopApp)
            desktopApp.Shutdown();
    }

    [RelayCommand]
    public void OpenApp()
    {
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktopApp)
        {
            // Get the main window
            var mainWindow = desktopApp.MainWindow as MainWindow;

            if (mainWindow != null)
            {
                // Show the main window and bring it to the front
                mainWindow.Show();
                mainWindow.WindowState = WindowState.Normal; // Ensure the window state is set to normal
                mainWindow.Activate();
            }
            else
            {
                // If the main window is null (i.e., it has been closed), create a new one
                var mainWindowViewModel =
                    ((App)Application.Current).ServiceProvider.GetRequiredService<MainWindowViewModel>();
                desktopApp.MainWindow = new MainWindow { DataContext = mainWindowViewModel };
                desktopApp.MainWindow.Show();
            }
        }
    }
}