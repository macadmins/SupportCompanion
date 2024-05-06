using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
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

    public MainWindowViewModel(ActionsService actionsService)

    {
        ShowHeader = !string.IsNullOrEmpty(App.Config.BrandName);
        BrandName = App.Config.BrandName;
        _actionsService = actionsService;
    }

    public bool ShowHeader { get; private set; }
    public string BrandName { get; private set; }
    public string appIconPath => "/usr/local/supportcompanion/appicon.ico";

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
            // Declare and initialize the mainWindow variable
            var mainWindow = desktopApp.MainWindow as MainWindow;

            // Check if the main window is hidden
            if (mainWindow?.IsVisible == true)
            {
                // Show the main window and bring it to the front
                mainWindow.Show();
                mainWindow.Activate();
            }
            else if (mainWindow == null || mainWindow.IsClosed)
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