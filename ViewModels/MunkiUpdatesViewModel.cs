using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MunkiUpdatesViewModel : ViewModelBase, IDisposable
{
    private readonly MunkiAppsService _munkiApps;
    private bool _disposed;
    private int _installedAppsCount;
    private int _munkiUpdatesCount;
    private Timer? _timer;

    public MunkiUpdatesViewModel(MunkiAppsService munkiApps)
    {
        _munkiApps = munkiApps;
        if (App.Config.MunkiMode)
        {
            MunkiUpdatesInfo = new MunkiUpdatesModel();
            _timer = new Timer(MunkiUpdatesCallback, null, 0, 60000);
        }
    }

    public MunkiUpdatesModel MunkiUpdatesInfo { get; }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    private async void MunkiUpdatesCallback(object state)
    {
        if (App.Config.MunkiMode)
            await GetInstallPercentage().ConfigureAwait(false);
    }

    private async Task GetMunkiUpdatesCount()
    {
        _munkiUpdatesCount = await _munkiApps.PendingUpdates();
        MunkiUpdatesInfo.PendingUpdates = _munkiUpdatesCount;
    }

    private async Task GetInstalledAppsCount()
    {
        _installedAppsCount = await _munkiApps.InstalledAppsCount();
        MunkiUpdatesInfo.InstalledApps = _installedAppsCount;
    }

    public async Task GetInstallPercentage()
    {
        Logger.LogWithSubsystem("MunkiUpdatesViewModel", "Getting Munki install percentage.", 1);
        await GetMunkiUpdatesCount();
        await GetInstalledAppsCount();

        var totalInstalled = MunkiUpdatesInfo.InstalledApps - MunkiUpdatesInfo.PendingUpdates;

        MunkiUpdatesInfo.InstallPercentage =
            Math.Round((double)totalInstalled / MunkiUpdatesInfo.InstalledApps * 100, 2);
    }

    private void CleanUp()
    {
        if (_timer != null)
        {
            _timer.Change(Timeout.Infinite, 0);
            _timer.Dispose();
            _timer = null;
        }
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();
            _disposed = true;
        }
    }

    ~MunkiUpdatesViewModel()
    {
        Dispose(false);
    }
}