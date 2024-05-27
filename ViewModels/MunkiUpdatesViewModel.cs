using Avalonia.Threading;
using ReactiveUI;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MunkiUpdatesViewModel : ViewModelBase, IWindowStateAware
{
    private readonly LoggerService _logger;
    private readonly MunkiAppsService _munkiApps;
    private int _installedAppsCount;
    private int _munkiUpdatesCount;

    private MunkiUpdatesModel? _munkiUpdatesInfo;
    private Timer? _timer;

    public MunkiUpdatesViewModel(MunkiAppsService munkiApps, LoggerService loggerService)
    {
        _munkiApps = munkiApps;
        _logger = loggerService;
        if (App.Config.MunkiMode && !App.Config.HiddenWidgets.Contains("MunkiUpdates"))
        {
            MunkiUpdatesInfo = new MunkiUpdatesModel();
            Dispatcher.UIThread.Post(InitializeAsync);
        }
    }

    public MunkiUpdatesModel? MunkiUpdatesInfo
    {
        get => _munkiUpdatesInfo;
        private set => this.RaiseAndSetIfChanged(ref _munkiUpdatesInfo, value);
    }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        if (App.Config.MunkiMode && !App.Config.HiddenWidgets.Contains("MunkiUpdates"))
        {
            MunkiUpdatesInfo = new MunkiUpdatesModel();
            Dispatcher.UIThread.Post(InitializeAsync);
        }
    }

    private async void InitializeAsync()
    {
        _timer ??= new Timer(async _ => await MunkiUpdatesCallback(), null, 0, 60000);
    }

    private async Task MunkiUpdatesCallback()
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

    private async Task GetInstallPercentage()
    {
        _logger.Log("MunkiUpdatesViewModel", "Getting Munki install percentage.", 1);
        await GetMunkiUpdatesCount();
        await GetInstalledAppsCount();

        var totalInstalled = MunkiUpdatesInfo.InstalledApps - MunkiUpdatesInfo.PendingUpdates;

        MunkiUpdatesInfo.InstallPercentage =
            Math.Round((double)totalInstalled / MunkiUpdatesInfo.InstalledApps * 100, 2);
    }

    private void StopTimer()
    {
        if (_timer == null) return;
        _logger.Log("MunkiUpdatesViewModel", "Stopping Munki Updates timer.", 1);
        _timer.Change(Timeout.Infinite, 0);
        _timer.Dispose();
        _timer = null;
    }

    private void CleanUp()
    {
        _installedAppsCount = 0;
        _munkiUpdatesCount = 0;
        MunkiUpdatesInfo = null;
        StopTimer();
    }
}