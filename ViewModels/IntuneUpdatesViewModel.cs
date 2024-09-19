using Avalonia.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using SupportCompanion.Interfaces;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public partial class IntuneUpdatesViewModel : ObservableObject, IWindowStateAware
{
    private readonly IntuneAppsService _intuneApps;
    private readonly LoggerService _logger;
    [ObservableProperty] private int _installPercentage;
    private int _intuneUpdatesCount;
    private Timer? _timer;

    public IntuneUpdatesViewModel(IntuneAppsService intuneApps, LoggerService loggerService)
    {
        _logger = loggerService;
        _intuneApps = intuneApps;
        if (App.Config.IntuneMode)
            Dispatcher.UIThread.Post(InitializeAsync);
    }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        if (App.Config.IntuneMode)
            Dispatcher.UIThread.Post(InitializeAsync);
    }

    private async void InitializeAsync()
    {
        _timer ??= new Timer(async _ => await IntuneUpdatesCallback(), null, 0, 60000);
    }

    private async Task IntuneUpdatesCallback()
    {
        if (App.Config.IntuneMode)
            await GetInstallPercentage().ConfigureAwait(false);
    }

    private async Task GetInstallPercentage()
    {
        _intuneUpdatesCount = 0;
        var policies = await _intuneApps.GetIntuneApps();
        if (policies.Count == 0) return;
        foreach (var app in policies)
            if (app.Value.ComplianceStateMessage.Applicability == 0
                && app.Value.EnforcementStateMessage.EnforcementState != 1000)
                _intuneUpdatesCount++;
        var totalInstalled = policies.Count - _intuneUpdatesCount;
        InstallPercentage = Convert.ToInt32(Math.Round((double)totalInstalled / policies.Count * 100, 2));
    }

    private void Stoptimer()
    {
        if (_timer == null) return;
        _logger.Log("IntuneUpdatesViewModel", "Stopping Intune Updates Timer", 1);
        _timer.Change(Timeout.Infinite, 0);
        _timer.Dispose();
        _timer = null;
    }

    private void CleanUp()
    {
        _intuneUpdatesCount = 0;
        InstallPercentage = 0;
        Stoptimer();
    }
}