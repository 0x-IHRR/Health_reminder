namespace HealthReminder.WindowsApp.SystemIntegration;

public interface IStartupManager
{
    void EnableOnFirstRun();
    bool IsStartupEnabled();
    void SetStartupEnabled(bool enabled);
}
