using System.Collections.ObjectModel;
using Avalonia.Threading;
using ReactiveUI;
using SupportCompanion.Interfaces;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class EvergreenWidgetViewModel : ViewModelBase, IWindowStateAware
{
    private readonly ObservableCollection<string> _catalogs = new();
    private readonly CatalogsService _catalogsService;
    private EvergreenInfoModel? _evergreenInfo;

    public EvergreenWidgetViewModel(CatalogsService catalogs)
    {
        if (App.Config.MunkiMode)
        {
            _catalogsService = catalogs;
            EvergreenInfo = new EvergreenInfoModel
            {
                Catalogs = _catalogs
            };
            Dispatcher.UIThread.Post(InitializeAsync);
        }
    }

    public EvergreenInfoModel? EvergreenInfo
    {
        get => _evergreenInfo;
        private set => this.RaiseAndSetIfChanged(ref _evergreenInfo, value);
    }

    public void OnWindowHidden()
    {
        CleanUp();
    }

    public void OnWindowShown()
    {
        if (App.Config.MunkiMode)
        {
            EvergreenInfo = new EvergreenInfoModel
            {
                Catalogs = _catalogs
            };
            Dispatcher.UIThread.Post(InitializeAsync);
        }
    }

    private async void InitializeAsync()
    {
        await DeviceCatalogs().ConfigureAwait(false);
    }

    private async Task DeviceCatalogs()
    {
        _catalogs.Clear(); // Clear the collection before fetching new catalogs
        var newCatalogs = await _catalogsService.GetCatalogs();
        foreach (var catalog in newCatalogs) _catalogs.Add(catalog); // Add new catalogs to the ObservableCollection
    }

    private void CleanUp()
    {
        _catalogs.Clear();
        EvergreenInfo = null;
    }
}