namespace SupportCompanion.Interfaces;

public interface INotification
{
    void SendNotification(string badgeText, string buttonText, string command);
}