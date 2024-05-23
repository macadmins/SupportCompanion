using SupportCompanion.Helpers;
using SupportCompanion.Interfaces;

namespace SupportCompanion.Services;

public class LoggerService : ILogger
{
    public void Log(string category, string message, int severity)
    {
        using var logger = new Logger();
        logger.LogWithSubsystem(category, message, severity);
    }
}