using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class NotificationService : INotification
{
    public NotificationService()
    {
        NSUserNotificationCenter.DefaultUserNotificationCenter.DidActivateNotification += (sender, args) =>
        {
            var command = args.Notification.UserInfo["Command"].ToString();
            var helper = new StartProcess();
            Logger.LogWithSubsystem(
                "NotificationService",
                $"Notification button clicked, running command: {command}",
                1);
            helper.RunCommandWithoutOutput(command);
        };
    }

    public void SendNotification(string message, string buttonText, string command)
    {
        var notification = new NSUserNotification
        {
            Title = App.Config.NotificationTitle,
            InformativeText = message,
            SoundName = NSUserNotification.NSUserNotificationDefaultSoundName,
            HasActionButton = true,
            ActionButtonTitle = buttonText,
            UserInfo = new NSDictionary("Command", command)
        };

        if (!string.IsNullOrEmpty(App.Config.NotificationImage))
            if (File.Exists(App.Config.NotificationImage))
            {
                Logger.LogWithSubsystem(
                    "NotificationService",
                    $"Notification image found: {App.Config.NotificationImage}",
                    1);
                notification.ContentImage = new NSImage(App.Config.NotificationImage);
            }
            else
            {
                Logger.LogWithSubsystem(
                    "NotificationService",
                    $"Notification image not found: {App.Config.NotificationImage}",
                    1);
            }

        Logger.LogWithSubsystem("NotificationService", $"Sending notification: {message}", 1);
        NSUserNotificationCenter.DefaultUserNotificationCenter.DeliverNotification(notification);
    }
}