namespace SupportCompanion.ViewModels;

public class HomeViewModel : ViewModelBase
{
    public HomeViewModel()
    {
        ShowDeviceWidget = !App.Config.HiddenWidgets.Contains("DeviceInfo");
        ShowMunkiPendingApps = !App.Config.HiddenWidgets.Contains("MunkiPendingApps") && App.Config.MunkiMode;
        ShowIntunePendingApps = !App.Config.HiddenWidgets.Contains("IntunePendingApps") && App.Config.IntuneMode;
        ShowMunkiUpdates = !App.Config.HiddenWidgets.Contains("MunkiUpdates") && App.Config.MunkiMode;
        ShowIntuneUpdates = !App.Config.HiddenWidgets.Contains("IntuneUpdates") && App.Config.IntuneMode;
        ShowStorage = !App.Config.HiddenWidgets.Contains("Storage");
        ShowMdmStatus = !App.Config.HiddenWidgets.Contains("MdmStatus");
        ShowActions = !App.Config.HiddenWidgets.Contains("Actions");
        ShowBattery = !App.Config.HiddenWidgets.Contains("Battery");
        ShowEvergreenInfo = !App.Config.HiddenWidgets.Contains("EvergreenInfo");
    }

    public bool ShowDeviceWidget { get; private set; }
    public bool ShowMunkiPendingApps { get; private set; }
    public bool ShowIntunePendingApps { get; private set; }
    public bool ShowMunkiUpdates { get; private set; }
    public bool ShowIntuneUpdates { get; private set; }
    public bool ShowStorage { get; private set; }
    public bool ShowMdmStatus { get; private set; }
    public bool ShowActions { get; private set; }
    public bool ShowBattery { get; private set; }
    public bool ShowEvergreenInfo { get; private set; }
}