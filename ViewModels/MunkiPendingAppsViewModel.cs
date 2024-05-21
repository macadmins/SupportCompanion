using System.Collections;
using System.Collections.ObjectModel;
using Avalonia.Threading;
using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MunkiPendingAppsViewModel : IDisposable
{
    private const string OpenMmcUpdates = "open munki://updates.html";
    private readonly MunkiAppsService _munkiApps;
    private bool _disposed;
    private IList _pendingAppsList = new List<string>();
    private Timer? _pendingAppsTimer;

    public MunkiPendingAppsViewModel(MunkiAppsService munkiApps)
    {
        if (App.Config.MunkiMode)
            _pendingAppsTimer = new Timer(MunkiPendingAppsCallback, null, 0, 60000);
        _munkiApps = munkiApps;
    }

    public ObservableCollection<MunkiPendingApp> PendingApps { get; } = new();

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    public void StopTimer()
    {
        if (_pendingAppsTimer != null)
        {
            _pendingAppsTimer.Change(Timeout.Infinite, 0);
            _pendingAppsTimer.Dispose();
            _pendingAppsTimer = null;
        }
    }

    private async void MunkiPendingAppsCallback(object state)
    {
        if (App.Config.MunkiMode)
            await GetPendingApps();
    }

    private async Task GetPendingApps()
    {
        Logger.LogWithSubsystem("MunkiPendingAppsViewModel", "Getting pending apps list.", 1);
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
        StopTimer();
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();

            _disposed = true;
        }
    }

    ~MunkiPendingAppsViewModel()
    {
        Dispose(false);
    }
}