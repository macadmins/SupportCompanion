namespace SupportCompanion.Interfaces;

public interface ILogger
{
    void Log(string category, string message, int severity);
}