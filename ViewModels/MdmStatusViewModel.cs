using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MdmStatusViewModel : ViewModelBase
{
    private readonly MdmStatusService _mdmStatusService;
    private bool _disposed;
    private Dictionary<string, string> _mdmStatus = new();

    public MdmStatusViewModel(MdmStatusService mdmStatus)
    {
        _mdmStatusService = mdmStatus;
        MdmStatusInfo = new MdmStatusModel();
        Initialization = InitializeAsync();
    }

    public MdmStatusModel MdmStatusInfo { get; }
    public Task Initialization { get; private set; }

    private async Task InitializeAsync()
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
        _mdmStatus.Clear();
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();
            _disposed = true;
        }
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    ~MdmStatusViewModel()
    {
        Dispose(false);
    }
}