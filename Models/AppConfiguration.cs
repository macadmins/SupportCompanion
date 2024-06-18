namespace SupportCompanion.Models;

public class AppConfiguration
{
    public string BundleId = "SupportCompanion";

    public List<string> Keys = new()
    {
        "BrandName", "CustomColors", "BrandColor", "HiddenWidgets", "SupportUrl", "ChangePasswordUrl",
        "ChangePasswordMode", "SupportEmail", "SupportPhone", "HiddenActions", "NotificationInterval",
        "NotificationTitle", "NotificationImage", "SoftwareUpdateNotificationMessage",
        "SoftwareUpdateNotificationButtonText", "AppUpdateNotificationMessage", "AppUpdateNotificationButtonText",
        "MunkiMode", "IntuneMode", "LogFolders", "Actions", "BrandLogo", "ShowMenuToggle", "ShowDesktopInfo", "FontSize",
        "DesktopPosition", "DesktopInfoLevel", "DesktopInfoColorHighlight", "DesktopInfoBackgroundColor", "DesktopInfoBackgroundOpacity",
        "DesktopInfoCustomItems"
    };

    public string BrandName { get; set; } = string.Empty;
    public string BrandColor { get; set; } = string.Empty;
    public string BrandLogo { get; set; } = string.Empty;
    public string SupportPageUrl { get; set; } = string.Empty;
    public string ChangePasswordUrl { get; set; } = string.Empty;
    public string ChangePasswordMode { get; set; } = "local";
    public string SupportEmail { get; set; } = string.Empty;
    public string SupportPhone { get; set; } = string.Empty;
    public List<string> HiddenWidgets { get; set; } = new() { "" };
    public List<string> HiddenActions { get; set; } = new() { "" };
    public List<string> LogFolders { get; set; } = new() { "/Library/Logs/Microsoft" };
    public int NotificationInterval { get; set; } = 4;
    public string NotificationTitle { get; set; } = "Support Companion \ud83d\udc4b";
    public string NotificationImage { get; set; } = string.Empty;

    public string SoftwareUpdateNotificationMessage { get; set; } =
        "You have software updates available. Take action now! \ud83c\udf89";

    public string SoftwareUpdateNotificationButtonText { get; set; } = "Details \ud83d\udc40";

    public string AppUpdateNotificationMessage { get; set; } =
        "You have app updates available. Take action now! \ud83c\udf89";

    public string AppUpdateNotificationButtonText { get; set; } = "Details \ud83d\udc40";
    public Dictionary<string, string> CustomColors { get; set; } = new();
    public bool MunkiMode { get; set; } = true;
    public bool IntuneMode { get; set; }
    public Dictionary<string, Dictionary<string, string>> Actions { get; set; } = new();
    public bool ShowMenuToggle { get; set; } = true;
    public bool ShowDesktopInfo { get; set; } = false;
    public int FontSize { get; set; } = 17;
    public string DesktopPosition { get; set; } = "TopRight";
    public string DesktopInfoLevel { get; set; } = "Full";
    public bool DesktopInfoColorHighlight { get; set; } = true;
    public string DesktopInfoBackgroundColor { get; set; } = "Transparent";
    public double DesktopInfoBackgroundOpacity { get; set; } = 1.0;
    public List<string> DesktopInfoCustomItems { get; set; } = new() { "" };
}