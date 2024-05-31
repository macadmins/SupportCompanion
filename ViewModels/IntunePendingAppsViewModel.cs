using System.Collections.ObjectModel;
using Avalonia.Threading;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class IntunePendingAppsViewModel : IWindowStateAware
{
    private const string OpenCompanyPortal = "open companyportal://";
    private readonly ActionsService _actions;
    private readonly IntuneAppsService _intuneApps;
    private readonly LoggerService _logger;
    private Timer? _pendingAppsTimer;
    private bool _showInfoIcon = true;

    public IntunePendingAppsViewModel(IntuneAppsService intuneApps, ActionsService actions, LoggerService loggerService)
    {
        if (App.Config.IntuneMode)
            Dispatcher.UIThread.Post(InitializeAsync);
        _intuneApps = intuneApps;
        _actions = actions;
        _logger = loggerService;
    }

    public ObservableCollection<IntunePendingApp> PendingApps { get; } = new();

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        if (App.Config.IntuneMode)
            Dispatcher.UIThread.Post(InitializeAsync);
    }

    private void StopTimer()
    {
        if (_pendingAppsTimer == null) return;
        _logger.Log("IntunePendingAppsViewModel", "Stopping Intune Pending Apps timer.", 1);
        _pendingAppsTimer.Change(Timeout.Infinite, 0);
        _pendingAppsTimer.Dispose();
        _pendingAppsTimer = null;
    }

    private async void InitializeAsync()
    {
        _pendingAppsTimer ??= new Timer(async _ => await GetIntunePendingAppsCallback(), null, 0, 60000);
    }

    private async Task GetIntunePendingAppsCallback()
    {
        if (App.Config.IntuneMode)
            await GetPendingApps().ConfigureAwait(false);
    }

    private async Task GetPendingApps()
    {
        _logger.Log("IntunePendingAppsViewModel", "Getting pending apps list.", 1);
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
                        PendingReason = $"{app.Value.ApplicationName}\n{app.Value.ErrorDetails}",
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
        StopTimer();
    }
}