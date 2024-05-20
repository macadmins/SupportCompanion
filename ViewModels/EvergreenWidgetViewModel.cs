using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class EvergreenWidgetViewModel : ViewModelBase, IDisposable
{
    private readonly CatalogsService _catalogsService;
    private List<string> _catalogs = new();
    private bool _disposed;

    public EvergreenWidgetViewModel(CatalogsService catalogs)
    {
        _catalogsService = catalogs;
        EvergreenInfo = new EvergreenInfoModel();
        if (App.Config.MunkiMode)
            InitializeAsync();
    }

    public EvergreenInfoModel? EvergreenInfo { get; private set; }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    private async void InitializeAsync()
    {
        await DeviceCatalogs().ConfigureAwait(false);
    }

    private async Task DeviceCatalogs()
    {
        _catalogs = await _catalogsService.GetCatalogs();
        EvergreenInfo.Catalogs = _catalogs;
    }

    private void CleanUp()
    {
        _catalogs.Clear();
        EvergreenInfo = null;
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();
            _disposed = true;
        }
    }

    ~EvergreenWidgetViewModel()
    {
        Dispose(false);
    }
}