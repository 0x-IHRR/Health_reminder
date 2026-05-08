namespace HealthReminder.WindowsApp.SystemIntegration;

public interface IIdleTimeProvider
{
    TimeSpan GetIdleTime();
}
