using CommunityToolkit.Mvvm.ComponentModel;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public partial class IntuneUpdatesViewModel : ObservableObject, IDisposable
{
    private readonly IntuneAppsService _intuneApps;
    private readonly Timer _timer;
    private int _installedAppsCount;

    [ObservableProperty] private int _installPercentage;

    private int _intuneUpdatesCount;

    public IntuneUpdatesViewModel(IntuneAppsService intuneApps)
    {
        _intuneApps = intuneApps;
        _timer = new Timer(IntuneUpdatesCallback, null, 0, 60000);
    }

    public void Dispose()
    {
        _timer?.Dispose();
    }

    private async void IntuneUpdatesCallback(object state)
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
}