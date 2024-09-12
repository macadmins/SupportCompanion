using System.Collections.ObjectModel;
using Newtonsoft.Json;
using ReactiveUI;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class HomeViewModel : ReactiveObject
{
    private readonly LoggerService _logger;

    private ObservableCollection<CustomWidgetsBaseViewModel> _customWidgets;

    public HomeViewModel() : this(new LoggerService())
    {
    }

    private HomeViewModel(LoggerService logger)
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
        ShowEvergreenInfo = !App.Config.HiddenWidgets.Contains("EvergreenInfo") && App.Config.MunkiMode;
        CustomWidgets = new ObservableCollection<CustomWidgetsBaseViewModel>();

        ShowUpdatesProgressPlaceholder = !App.Config.IntuneMode ||
                                         !App.Config.MunkiMode ||
                                         !App.Config.HiddenWidgets.Contains("MunkiUpdates") ||
                                         !App.Config.HiddenWidgets.Contains("IntuneUpdates");

        ShowAppsListPlaceholder = App.Config.IntuneMode ||
                                  App.Config.MunkiMode ||
                                  !App.Config.HiddenWidgets.Contains("MunkiPendingApps") ||
                                  !App.Config.HiddenWidgets.Contains("IntunePendingApps");
        ShowDeviceWidgetPlaceholder = App.Config.HiddenWidgets.Contains("DeviceInfo");
        ShowStoragePlaceholder = App.Config.HiddenWidgets.Contains("Storage");
        ShowMdmPlaceholder = App.Config.HiddenWidgets.Contains("MdmStatus");
        ShowEvergreenInfoPlaceholder = App.Config.HiddenWidgets.Contains("EvergreenInfo") || !App.Config.MunkiMode;
        ShowBatteryPlaceholder = App.Config.HiddenWidgets.Contains("Battery");
        ShowActionsPlaceholder = App.Config.HiddenWidgets.Contains("Actions");

        _logger = logger;
    }

    public ObservableCollection<CustomWidgetsBaseViewModel> CustomWidgets
    {
        get => _customWidgets;
        set => this.RaiseAndSetIfChanged(ref _customWidgets, value);
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
    public bool ShowUpdatesProgressPlaceholder { get; private set; }
    public bool ShowAppsListPlaceholder { get; private set; }
    public bool ShowDeviceWidgetPlaceholder { get; private set; }
    public bool ShowStoragePlaceholder { get; private set; }
    public bool ShowMdmPlaceholder { get; private set; }
    public bool ShowEvergreenInfoPlaceholder { get; private set; }
    public bool ShowBatteryPlaceholder { get; private set; }
    public bool ShowActionsPlaceholder { get; private set; }

    public async void LoadCustomWidgets(string jsonPath)
    {
        if (File.Exists(jsonPath))
            try
            {
                CustomWidgets.Clear();
                var json = await File.ReadAllTextAsync(jsonPath);

                var widgets = JsonConvert.DeserializeObject<List<CustomWidgetsBaseViewModel>>(json);
                if (widgets != null)
                    foreach (var widget in widgets)
                    {
                        _logger.Log("LoadCustomWidgets", "Adding custom widget: " + widget.Header, 1);
                        CustomWidgets.Add(widget);
                    }
                else
                    _logger.Log("LoadCustomWidgets", "No widgets found in JSON", 1);
            }
            catch (Exception e)
            {
                _logger.Log("LoadCustomWidgets", "Error loading custom widgets: " + e.Message, 2);
            }
        else
            _logger.Log("LoadCustomWidgets", "Custom widgets JSON file not found", 1);
    }
}