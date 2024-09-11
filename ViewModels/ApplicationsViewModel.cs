using System.Collections;
using System.Collections.ObjectModel;
using Avalonia.Threading;
using ReactiveUI;
using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;
using MunkiApps = SupportCompanion.Helpers.MunkiApps;

namespace SupportCompanion.ViewModels;

public class ApplicationsViewModel : ViewModelBase, IWindowStateAware
{
    private readonly ActionsService _actions;
    private readonly IntuneAppsService _intuneApps;
    private readonly LoggerService _logger;
    private IList _installedAppsList = new List<string>();
    private IList _selfServeAppsList = new List<string>();
    private Timer? _timer;
    private bool _isLoading;
    public bool IsLoading
    {
        get => _isLoading;
        set => this.RaiseAndSetIfChanged(ref _isLoading, value);
    }

    public ApplicationsViewModel(ActionsService actions, IntuneAppsService intuneApps, LoggerService loggerService)
    {
        _actions = actions;
        _intuneApps = intuneApps;
        _logger = loggerService;
        Dispatcher.UIThread.Post(InitializeAsync);
        ShowActionButton = App.Config.MunkiMode;
    }

    public bool ShowActionButton { get; }
    public bool ShowArch { get; } = App.Config.AppProfilerMode;

    public ObservableCollection<InstalledApp> InstalledApps { get; } = new();

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        Dispatcher.UIThread.Post(InitializeAsync);
    }

    private void StopTimer()
    {
        if (_timer == null) return;
        _logger.Log("ApplicationsViewModel", "Stopping Applications timer", 1);
        _timer.Change(Timeout.Infinite, 0);
        _timer.Dispose();
        _timer = null;
    }

    private async void InitializeAsync()
    {
        var interval = (int)TimeSpan.FromMinutes(10).TotalMilliseconds;
        _timer ??= new Timer(async _ => await ApplicationsCallback(), null, 0, interval);
    }

    private async Task ApplicationsCallback()
    {
        if (App.Config.MunkiMode)
            await GetInstalledApps();
        else if (App.Config.IntuneMode)
            await GetIntuneInstalledApps();
        else if (App.Config.AppProfilerMode)
            await GetSystemProfilerApps();
    }

    public async Task ManageAppClick(string action)
    {
        await _actions.RunCommandWithoutOutput(action);
    }

    private async Task GetInstalledApps()
    {
        _logger.Log("ApplicationsViewModel", "Getting installed apps list", 1);
        _selfServeAppsList = await new MunkiApps().GetSelfServeAppsList();
        _installedAppsList = await new MunkiApps().GetInstalledAppsList();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            InstalledApps.Clear();
            foreach (var app in _installedAppsList)
            {
                var appDict = (IDictionary<string, object>)app;
                // Check if installed is true
                if (appDict["installed"].ToString() == "True")
                {
                    var name = appDict["display_name"].ToString();
                    var version = appDict["installed_version"].ToString();
                    // get the name with spaces replaced with %20
                    var commandName = name.Replace(" ", "%20");
                    var command = $"open \"munki://detail-{commandName}\"";
                    var action = string.Empty;
                    var isSelfServe = false;
                    if (_selfServeAppsList.Contains(name))
                    {
                        action = command;
                        isSelfServe = true;
                    }

                    InstalledApps.Add(new InstalledApp(name, version, action, string.Empty ,isSelfServe));
                }
            }
        });
    }

    private async Task GetIntuneInstalledApps()
    {
        var policies = await _intuneApps.GetIntuneApps();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            InstalledApps.Clear();
            foreach (var app in policies)
            {
                if (app.Value.ComplianceStateMessage.Applicability == 0
                    && app.Value.EnforcementStateMessage.EnforcementState != 1000)
                    continue;
                var name = app.Value.ApplicationName;
                var version = app.Value.ComplianceStateMessage.ProductVersion;
                InstalledApps.Add(new InstalledApp(name, version, string.Empty, string.Empty));
            }
        });
    }

    private async Task GetSystemProfilerApps()
    {
        IsLoading = true;
        var apps = await new ProfilerApplications().GetInstalledApps();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            InstalledApps.Clear();
            foreach (var app in apps)
            {
                var installedApp = app as InstalledAppProfiler;
                InstalledApps.Add(new InstalledApp(installedApp.Name, installedApp.Version, string.Empty, installedApp.Arch));
            }
        });
        IsLoading = false;
    }
    private void CleanUp()
    {
        InstalledApps.Clear();
        _installedAppsList.Clear();
        _selfServeAppsList.Clear();
        StopTimer();
    }
}