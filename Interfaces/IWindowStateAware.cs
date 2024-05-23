namespace SupportCompanion.Interfaces;

public interface IWindowStateAware
{
    void OnWindowHidden();
    void OnWindowShown();
}