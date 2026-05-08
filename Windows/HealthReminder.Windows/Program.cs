using HealthReminder.WindowsApp.SystemIntegration;
using HealthReminder.WindowsApp.Tray;
using System.Windows.Forms;

namespace HealthReminder.WindowsApp;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using Mutex mutex = new(true, "Local\\HealthReminder.Windows.SingleInstance", out bool createdNew);
        if (!createdNew)
        {
            return;
        }

        ApplicationConfiguration.Initialize();
        using HealthReminderApplicationContext context = new(
            new WindowsIdleTimeProvider(),
            new RegistryStartupManager()
        );
        Application.Run(context);
    }
}
