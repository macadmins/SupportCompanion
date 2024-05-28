using Avalonia.Media;
using CoreFoundation;
using SukiUI;
using SukiUI.Enums;
using SukiUI.Models;
using SupportCompanion.Models;

namespace SupportCompanion.Helpers;

public class AppConfigHelper
{
    public static AppConfiguration Config { get; private set; }

    public void SetPrefs()
    {
        Config = new AppConfiguration();
        var bundleId = Config.BundleId;
        var prefs = new Dictionary<string, object>();
        var keys = Config.Keys;
        foreach (var pref in keys)
        {
            var preference = CFPreferences.GetAppValue(pref, bundleId);
            if (preference != null) prefs.Add(pref, preference);
        }
        
        foreach (var pref in prefs)
            switch (pref.Key)
            {
                case "BrandName":
                    Config.BrandName = pref.Value as NSString;
                    break;
                case "BrandColor":
                    Config.BrandColor = pref.Value as NSString;
                    break;
                case "SupportUrl":
                    Config.SupportPageUrl = pref.Value as NSString;
                    break;
                case "ChangePasswordUrl":
                    Config.ChangePasswordUrl = pref.Value as NSString;
                    break;
                case "ChangePasswordMode":
                    Config.ChangePasswordMode = pref.Value as NSString;
                    break;
                case "SupportEmail":
                    Config.SupportEmail = pref.Value as NSString;
                    break;
                case "SupportPhone":
                    Config.SupportPhone = pref.Value as NSString;
                    break;
                case "NotificationInterval":
                    if (pref.Value is Foundation.NSNumber number)
                    {
                        Config.NotificationInterval = number.Int32Value;
                    }
                    else if (pref.Value is Foundation.NSString nsString)
                    {
                        Config.NotificationInterval = int.Parse(nsString.ToString());
                    }
                    break;
                case "NotificationTitle":
                    Config.NotificationTitle = pref.Value as NSString;
                    break;
                case "NotificationImage":
                    Config.NotificationImage = pref.Value as NSString;
                    break;
                case "SoftwareUpdateNotificationMessage":
                    Config.SoftwareUpdateNotificationMessage = pref.Value as NSString;
                    break;
                case "SoftwareUpdateNotificationButtonText":
                    Config.SoftwareUpdateNotificationButtonText = pref.Value as NSString;
                    break;
                case "AppUpdateNotificationMessage":
                    Config.AppUpdateNotificationMessage = pref.Value as NSString;
                    break;
                case "AppUpdateNotificationButtonText":
                    Config.AppUpdateNotificationButtonText = pref.Value as NSString;
                    break;
                case "HiddenActions":
                    if (pref.Value is NSMutableArray hiddenActionsArray)
                    {
                        Config.HiddenActions = new List<string>();
                        foreach (var action in hiddenActionsArray)
                            if (action is NSString hiddenAction)
                                Config.HiddenActions.Add(hiddenAction.ToString());
                    }

                    break;
                case "HiddenWidgets":
                    if (pref.Value is NSMutableArray hiddenWidgetsArray)
                    {
                        Config.HiddenWidgets = new List<string>();
                        foreach (var widget in hiddenWidgetsArray)
                            if (widget is NSString hiddenWidget)
                                Config.HiddenWidgets.Add(hiddenWidget.ToString());
                    }

                    break;
                case "CustomColors":
                    if (pref.Value is NSMutableArray customColorsArray)
                    {
                        Config.CustomColors = new Dictionary<string, string>();
                        foreach (var color in customColorsArray)
                            if (color is NSDictionary colorDict)
                                foreach (var key in colorDict.Keys)
                                    if (key is NSString colorKey && colorDict[colorKey] is NSString colorValue)
                                        Config.CustomColors.Add(colorKey.ToString(), colorValue.ToString());
                    }

                    break;
                case "Actions":
                    if (pref.Value is NSMutableArray actionsArray)
                    {
                        Config.Actions = new Dictionary<string, Dictionary<string, string>>();
                        foreach (var action in actionsArray)
                            if (action is NSDictionary actionDict)
                            {
                                var actionEntry = new Dictionary<string, string>();
                                string actionName = null;

                                foreach (var key in actionDict.Keys)
                                    if (key is NSString actionKey && actionDict[actionKey] is NSString actionValue)
                                    {
                                        if (actionKey.ToString() == "Name") actionName = actionValue.ToString();
                                        actionEntry[actionKey.ToString()] = actionValue.ToString();
                                    }

                                if (actionName != null) Config.Actions[actionName] = actionEntry;
                            }
                    }

                    break;
                case "LogFolders":
                    if (pref.Value is NSMutableArray logFoldersArray)
                    {
                        Config.LogFolders = new List<string>();
                        foreach (var folder in logFoldersArray)
                            if (folder is NSString logFolder)
                                Config.LogFolders.Add(logFolder.ToString());
                    }

                    break;
                case "IntuneMode":
                    Config.IntuneMode = (bool)pref.Value;
                    break;
            }

        if (!string.IsNullOrEmpty(Config.BrandColor))
        {
            switch (Config.BrandColor)
            {
                case "Blue":
                    SukiTheme.GetInstance().ChangeColorTheme(SukiColor.Blue);
                    break;
                case "Green":
                    SukiTheme.GetInstance().ChangeColorTheme(SukiColor.Green);
                    break;
                case "Red":
                    SukiTheme.GetInstance().ChangeColorTheme(SukiColor.Red);
                    break;
                case "Orange":
                    SukiTheme.GetInstance().ChangeColorTheme(SukiColor.Orange);
                    break;
            }
        }
        else if (Config.CustomColors.Count > 0)
        {
            Color primary = default;
            Color accent = default;

            foreach (var color in Config.CustomColors)
            {
                if (color.Key == "PrimaryColor") primary = Color.Parse(color.Value);

                if (color.Key == "AccentColor") accent = Color.Parse(color.Value);
            }

            var CustomTheme = new SukiColorTheme("Custom", primary, accent);
            SukiTheme.GetInstance().AddColorTheme(CustomTheme);
            SukiTheme.GetInstance().ChangeColorTheme(CustomTheme);
        }
        else
        {
            // Set a default color theme if no other color is set
            SukiTheme.GetInstance().ChangeColorTheme(SukiColor.Blue);
        }
    }
}