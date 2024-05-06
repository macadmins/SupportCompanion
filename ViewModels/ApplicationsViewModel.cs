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
    private IList _installedAppsList = new List<string>();
    private IList _selfServeAppsList = new List<string>();
    private readonly Timer _timer;

    public ApplicationsViewModel(ActionsService actions)
    {
        _actions = actions;
        GetInstalledApps();
        _timer = new Timer(ApplicationsCallback, null, 0, 300000);
    }

    public ObservableCollection<InstalledApp> InstalledApps { get; } = new();

    public void Dispose()
    {
        _timer?.Dispose();
    }

    private async void ApplicationsCallback(object state)
    {
        await GetInstalledApps();
    }

    public async Task ManageAppClick(string action)
    {
        await _actions.RunCommandWithoutOutput(action);
        Console.WriteLine(action);
    }

    private async Task GetInstalledApps()
    {
        Logger.LogWithSubsystem("ApplicationsViewModel", "Getting installed apps list", 1);
        _selfServeAppsList = await new MunkiApps().GetSelfServeAppsList();
        _installedAppsList = await new MunkiApps().GetInstalledAppsList();
        var installedAppsList = new List<InstalledApp>();
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
}