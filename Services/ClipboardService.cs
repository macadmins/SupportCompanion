using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using IClipboard = SupportCompanion.Interfaces.IClipboard;

namespace SupportCompanion.Services;

public class ClipboardService : IClipboard
{
    private readonly LoggerService _logger;

    public ClipboardService(LoggerService loggerService)
    {
        _logger = loggerService;
    }

    public async Task SetClipboardTextAsync(string text)
    {
        if (Application.Current?.ApplicationLifetime is not IClassicDesktopStyleApplicationLifetime desktop ||
            desktop.MainWindow?.Clipboard is not { } provider)
            throw new NullReferenceException("Missing Clipboard instance.");

        await provider.SetTextAsync(text);
    }

    public async Task<string> GetClipboardTextAsync()
    {
        if (Application.Current?.ApplicationLifetime is not IClassicDesktopStyleApplicationLifetime desktop ||
            desktop.MainWindow?.Clipboard is not { } provider)
        {
            _logger.Log("ClipboardService:GetClipboardTextAsync", "Missing Clipboard instance.", 2);
            return string.Empty;
        }

        return await provider.GetTextAsync();
    }
}