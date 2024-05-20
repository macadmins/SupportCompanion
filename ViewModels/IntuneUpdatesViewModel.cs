using CommunityToolkit.Mvvm.ComponentModel;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public partial class IntuneUpdatesViewModel : ObservableObject, IDisposable
{
    private readonly IntuneAppsService _intuneApps;
    private bool _disposed;
    private int _installedAppsCount;
    [ObservableProperty] private int _installPercentage;

    private int _intuneUpdatesCount;
    private Timer? _timer;

    public IntuneUpdatesViewModel(IntuneAppsService intuneApps)
    {
        _intuneApps = intuneApps;
        if (App.Config.IntuneMode)
            _timer = new Timer(IntuneUpdatesCallback, null, 0, 60000);
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
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

    ~IntuneUpdatesViewModel()
    {
        Dispose(false);
    }
}