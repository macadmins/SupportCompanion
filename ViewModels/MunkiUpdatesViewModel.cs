using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MunkiUpdatesViewModel : ViewModelBase
{
    private readonly MunkiAppsService _munkiApps;
    private int _installedAppsCount;
    private int _munkiUpdatesCount;
    private Timer _timer;

    public MunkiUpdatesViewModel(MunkiAppsService munkiApps)
    {
        _munkiApps = munkiApps;
        MunkiUpdatesInfo = new MunkiUpdatesModel();
        _timer = new Timer(MunkiUpdatesCallback, null, 0, 60000);
    }

    public MunkiUpdatesModel MunkiUpdatesInfo { get; }

    private async void MunkiUpdatesCallback(object state)
    {
        await GetInstallPercentage();
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