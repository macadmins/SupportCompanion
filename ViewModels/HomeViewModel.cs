namespace SupportCompanion.ViewModels;

public class HomeViewModel : ViewModelBase
{
    public HomeViewModel()
    {
        ShowDeviceWidget = !App.Config.HiddenWidgets.Contains("DeviceInfo");
        ShowMunkiPendingApps = !App.Config.HiddenWidgets.Contains("MunkiPendingApps");
        ShowMunkiUpdates = !App.Config.HiddenWidgets.Contains("MunkiUpdates");
        ShowStorage = !App.Config.HiddenWidgets.Contains("Storage");
        ShowMdmStatus = !App.Config.HiddenWidgets.Contains("MdmStatus");
        ShowActions = !App.Config.HiddenWidgets.Contains("Actions");
        ShowBattery = !App.Config.HiddenWidgets.Contains("Battery");
        ShowEvergreenInfo = !App.Config.HiddenWidgets.Contains("EvergreenInfo");
    }

    public bool ShowDeviceWidget { get; private set; }
    public bool ShowMunkiPendingApps { get; private set; }
    public bool ShowMunkiUpdates { get; private set; }
    public bool ShowStorage { get; private set; }
    public bool ShowMdmStatus { get; private set; }
    public bool ShowActions { get; private set; }
    public bool ShowBattery { get; private set; }
    public bool ShowEvergreenInfo { get; private set; }
}