namespace SupportCompanion.Interfaces;

public interface IActions
{
    public Task KillAgent();
    public Task Reboot();
    public Task ManagedSoftwareCenter();
    public Task MmcUpdates();
    public Task OpenSupportPage();
    public Task RunCommandWithoutOutput(string command);
    public Task<string> RunCommandWithOutput(string command);
}