using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class NotificationService : INotification
{
    private readonly LoggerService _logger;

    public NotificationService(LoggerService loggerService)
    {
        _logger = loggerService;
    }

    public NotificationService()
    {
        NSUserNotificationCenter.DefaultUserNotificationCenter.DidActivateNotification += (sender, args) =>
        {
            var command = args.Notification.UserInfo["Command"].ToString();
            var helper = new StartProcess();
            _logger.Log(
                "NotificationService",
                $"Notification button clicked, running command: {command}",
                1);
            helper.RunCommandWithoutOutput(command);
        };
    }

    public void SendNotification(string message, string buttonText, string command)
    {
        if (App.Config.NotificationInterval == 0)
        {
            _logger.Log(
                "NotificationService",
                "Notification interval set to 0, skipping notification",
                1);
            return;
        }

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
                _logger.Log(
                    "NotificationService",
                    $"Notification image found: {App.Config.NotificationImage}",
                    1);
                notification.ContentImage = new NSImage(App.Config.NotificationImage);
            }
            else
            {
                _logger.Log(
                    "NotificationService",
                    $"Notification image not found: {App.Config.NotificationImage}",
                    1);
            }

        _logger.Log("NotificationService", $"Sending notification: {message}", 1);
        NSUserNotificationCenter.DefaultUserNotificationCenter.DeliverNotification(notification);
    }
}