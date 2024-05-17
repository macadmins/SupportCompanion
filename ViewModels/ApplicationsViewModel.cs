using System.Collections;
using System.Collections.ObjectModel;
using Avalonia.Threading;
using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;
using MunkiApps = SupportCompanion.Helpers.MunkiApps;

namespace SupportCompanion.ViewModels;

public class ApplicationsViewModel : ViewModelBase, IDisposable
{
    private readonly ActionsService _actions;
    private readonly IntuneAppsService _intuneApps;
    private readonly Timer _timer;
    private IList _installedAppsList = new List<string>();
    private IList _selfServeAppsList = new List<string>();

    public ApplicationsViewModel(ActionsService actions, IntuneAppsService intuneApps)
    {
        _actions = actions;
        _intuneApps = intuneApps;
        var interval = (int)TimeSpan.FromMinutes(10).TotalMilliseconds;
        _timer = new Timer(ApplicationsCallback, null, 0, interval);
        ShowActionButton = App.Config.MunkiMode;
    }

    public bool ShowActionButton { get; }

    public ObservableCollection<InstalledApp> InstalledApps { get; } = new();

    public void Dispose()
    {
        _timer?.Dispose();
    }

    private async void ApplicationsCallback(object state)
    {
        if (App.Config.MunkiMode)
            await GetInstalledApps();
        else if (App.Config.IntuneMode)
            await GetIntuneInstalledApps();
    }

    public async Task ManageAppClick(string action)
    {
        await _actions.RunCommandWithoutOutput(action);
    }

    private async Task GetInstalledApps()
    {
        Logger.LogWithSubsystem("ApplicationsViewModel", "Getting installed apps list", 1);
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

                    InstalledApps.Add(new InstalledApp(name, version, action, isSelfServe));
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
                InstalledApps.Add(new InstalledApp(name, version, string.Empty));
            }
        });
    }
}