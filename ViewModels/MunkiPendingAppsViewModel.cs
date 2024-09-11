using System.Collections;
using System.Collections.ObjectModel;
using Avalonia.Threading;
using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MunkiPendingAppsViewModel : IWindowStateAware
{
    private const string OpenMmcUpdates = "open munki://updates.html";
    private readonly LoggerService _logger;
    private readonly MunkiAppsService _munkiApps;
    private IList _pendingAppsList = new List<string>();
    private Timer? _pendingAppsTimer;
    public bool ShowData { get; private set; } = true;
    public bool ShowGrid { get; private set; } = true;

    public MunkiPendingAppsViewModel(MunkiAppsService munkiApps, LoggerService loggerService)
    {
        if (App.Config.MunkiMode && App.Config.HiddenWidgets.Contains("MunkiPendingApps") == false)
            Dispatcher.UIThread.Post(InitializeAsync);
        if (App.Config.HiddenWidgets.Contains("MunkiPendingApps") || !App.Config.MunkiMode)
        {
            ShowData = false;
            if (App.Config.IntuneMode)
                ShowGrid = false;
        }
        _munkiApps = munkiApps;
        _logger = loggerService;
    }

    public ObservableCollection<MunkiPendingApp> PendingApps { get; } = new();

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        if (App.Config.MunkiMode && App.Config.HiddenWidgets.Contains("MunkiPendingApps") == false)
            Dispatcher.UIThread.Post(InitializeAsync);
    }

    private void StopTimer()
    {
        if (_pendingAppsTimer == null) return;
        _logger.Log("MunkiPendingAppsViewModel", "Stopping Munki Pending Apps timer.", 1);
        _pendingAppsTimer.Change(Timeout.Infinite, 0);
        _pendingAppsTimer.Dispose();
        _pendingAppsTimer = null;
    }

    private async void InitializeAsync()
    {
        _pendingAppsTimer ??= new Timer(async _ => await MunkiPendingAppsCallback(), null, 0, 60000);
    }

    private async Task MunkiPendingAppsCallback()
    {
        if (App.Config.MunkiMode) await GetPendingApps();
    }

    private async Task GetPendingApps()
    {
        _logger.Log("MunkiPendingAppsViewModel", "Getting pending apps list.", 1);
        _pendingAppsList = await _munkiApps.GetPendingUpdatesList();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            PendingApps.Clear();
            foreach (var app in _pendingAppsList)
            {
                var appDict = (IDictionary<string, object>)app;
                var name = appDict["display_name"].ToString();
                var version = appDict["version_to_install"].ToString();
                PendingApps.Add(new MunkiPendingApp(name, version));
            }
        });
    }

    public async Task MmcUpdates()
    {
        var helper = new StartProcess();
        await helper.RunCommandWithoutOutput(OpenMmcUpdates);
    }

    private void CleanUp()
    {
        PendingApps.Clear();
        _pendingAppsList.Clear();
        StopTimer();
    }
}