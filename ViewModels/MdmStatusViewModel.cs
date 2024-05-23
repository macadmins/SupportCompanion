using Avalonia.Threading;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MdmStatusViewModel : ViewModelBase, IWindowStateAware
{
    private readonly MdmStatusService _mdmStatusService;
    private bool _disposed;
    private Dictionary<string, string> _mdmStatus = new();

    public MdmStatusViewModel(MdmStatusService mdmStatus)
    {
        _mdmStatusService = mdmStatus;
        MdmStatusInfo = new MdmStatusModel();
        Dispatcher.UIThread.Post(InitializeAsync);
    }

    public MdmStatusModel? MdmStatusInfo { get; private set; }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        MdmStatusInfo = new MdmStatusModel();
        Dispatcher.UIThread.Post(InitializeAsync);
    }

    private async void InitializeAsync()
    {
        await GetMdmDetails().ConfigureAwait(false);
    }

    private async Task GetMdmDetails()
    {
        _mdmStatus = await _mdmStatusService.GetMdmStatus();
        // Set the properties of the MDMStatusModel
        MdmStatusInfo.Abm = _mdmStatus["ABM"];
        MdmStatusInfo.Enrolled = _mdmStatus["enrolled"];
        MdmStatusInfo.EnrollmentDate = _mdmStatus["enrollmentDate"];
    }

    private void CleanUp()
    {
        MdmStatusInfo = null;
        _mdmStatus.Clear();
    }

    private void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();
            _disposed = true;
            GC.SuppressFinalize(this);
        }
    }
}