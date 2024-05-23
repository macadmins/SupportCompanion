using Avalonia.Threading;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class EvergreenWidgetViewModel : ViewModelBase, IWindowStateAware
{
    private readonly CatalogsService _catalogsService;
    private List<string> _catalogs = new();

    public EvergreenWidgetViewModel(CatalogsService catalogs)
    {
        _catalogsService = catalogs;
        if (App.Config.MunkiMode)
        {
            EvergreenInfo = new EvergreenInfoModel();
            Dispatcher.UIThread.Post(InitializeAsync);
        }
    }

    public EvergreenInfoModel? EvergreenInfo { get; private set; }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        if (App.Config.MunkiMode)
        {
            EvergreenInfo = new EvergreenInfoModel();
            Dispatcher.UIThread.Post(InitializeAsync);
        }
    }

    private async void InitializeAsync()
    {
        await DeviceCatalogs().ConfigureAwait(false);
    }

    private async Task DeviceCatalogs()
    {
        EvergreenInfo?.Catalogs?.Clear();
        _catalogs = await _catalogsService.GetCatalogs();
        EvergreenInfo.Catalogs = _catalogs;
    }

    private void CleanUp()
    {
        _catalogs.Clear();
        EvergreenInfo = null;
    }
}