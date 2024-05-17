namespace SupportCompanion.Helpers;

public static class NotificationTimeStamp
{
    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "SupportCompanion");

    public static DateTime? ReadLastNotificationTime(string cacheName)
    {
        var cachePath = Path.Combine(FilePath, cacheName);
        if (File.Exists(cachePath))
        {
            var content = File.ReadAllText(cachePath);
            if (DateTime.TryParse(content, out var lastNotificationTime)) return lastNotificationTime;
        }

        return null;
    }

    public static void WriteLastNotificationTime(DateTime dateTime, string cacheName)
    {
        var cachePath = Path.Combine(FilePath, cacheName);
        var directory = Path.GetDirectoryName(cachePath);
        if (directory != null) Directory.CreateDirectory(directory);
        File.WriteAllText(cachePath, dateTime.ToString("o")); // "o" for round-trip date/time pattern
    }
}