using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MdmStatusViewModel : ViewModelBase
{
    private readonly MdmStatusService _mdmStatusService;
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
        await GetMdmDetails();
    }

    private async Task GetMdmDetails()
    {
        _mdmStatus = await _mdmStatusService.GetMdmStatus();
        // Set the properties of the MDMStatusModel
        MdmStatusInfo.Abm = _mdmStatus["ABM"];
        MdmStatusInfo.Enrolled = _mdmStatus["enrolled"];
        MdmStatusInfo.EnrollmentDate = _mdmStatus["enrollmentDate"];
    }
}