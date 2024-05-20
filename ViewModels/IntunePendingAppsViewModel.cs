using System.Collections.ObjectModel;
using Avalonia.Threading;
using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class IntunePendingAppsViewModel : IDisposable
{
    private const string OpenCompanyPortal = "open companyportal://";
    private readonly ActionsService _actions;
    private readonly IntuneAppsService _intuneApps;
    private bool _disposed;
    private Timer? _pendingAppsTimer;
    private bool _showInfoIcon = true;

    public IntunePendingAppsViewModel(IntuneAppsService intuneApps, ActionsService actions)
    {
        if (App.Config.IntuneMode)
            _pendingAppsTimer = new Timer(IntunePendingAppsCallback, null, 0, 60000);
        _intuneApps = intuneApps;
        _actions = actions;
    }

    public ObservableCollection<IntunePendingApp> PendingApps { get; } = new();

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    private async void IntunePendingAppsCallback(object state)
    {
        if (App.Config.IntuneMode)
            await GetPendingApps();
    }

    private async Task GetPendingApps()
    {
        Logger.LogWithSubsystem("IntunePendingAppsViewModel", "Getting pending apps list.", 1);
        var policies = await _intuneApps.GetIntuneApps();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            PendingApps.Clear();
            foreach (var app in policies)
                if (app.Value.ComplianceStateMessage.Applicability == 0
                    && app.Value.EnforcementStateMessage.EnforcementState != 1000)
                {
                    if (string.IsNullOrEmpty(app.Value.ErrorDetails)) _showInfoIcon = false;
                    PendingApps.Add(new IntunePendingApp
                    {
                        Name = app.Value.ApplicationName,
                        PendingReason = app.Value.ErrorDetails,
                        ShowInfoIcon = _showInfoIcon
                    });
                }
        });
    }

    public async Task CompanyPortal()
    {
        await _actions.RunCommandWithoutOutput(OpenCompanyPortal);
    }

    private void CleanUp()
    {
        PendingApps.Clear();
        if (_pendingAppsTimer != null)
        {
            _pendingAppsTimer.Change(Timeout.Infinite, 0);
            _pendingAppsTimer.Dispose();
            _pendingAppsTimer = null;
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

    ~IntunePendingAppsViewModel()
    {
        Dispose(false);
    }
}