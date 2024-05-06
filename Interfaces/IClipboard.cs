namespace SupportCompanion.Interfaces;

public interface IClipboard
{
    Task SetClipboardTextAsync(string text);
    Task<string> GetClipboardTextAsync();
}