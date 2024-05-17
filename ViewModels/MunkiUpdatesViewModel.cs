using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MunkiUpdatesViewModel : ViewModelBase, IDisposable
{
    private readonly MunkiAppsService _munkiApps;
    private readonly Timer _timer;
    private int _installedAppsCount;
    private int _munkiUpdatesCount;

    public MunkiUpdatesViewModel(MunkiAppsService munkiApps)
    {
        _munkiApps = munkiApps;
        MunkiUpdatesInfo = new MunkiUpdatesModel();
        _timer = new Timer(MunkiUpdatesCallback, null, 0, 60000);
    }

    public MunkiUpdatesModel MunkiUpdatesInfo { get; }

    public void Dispose()
    {
        _timer?.Dispose();
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
}