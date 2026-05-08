using Microsoft.Win32;
using System.Windows.Forms;

namespace HealthReminder.WindowsApp.SystemIntegration;

public sealed class RegistryStartupManager : IStartupManager
{
    private const string AppName = "HealthReminder";
    private const string AppKeyPath = @"Software\HealthReminder";
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string StartupConfiguredValue = "StartupConfigured";

    private readonly string _executablePath;

    public RegistryStartupManager()
        : this(Application.ExecutablePath)
    {
    }

    internal RegistryStartupManager(string executablePath)
    {
        _executablePath = executablePath;
    }

    public void EnableOnFirstRun()
    {
        using RegistryKey appKey = Registry.CurrentUser.CreateSubKey(AppKeyPath, writable: true);
        if (appKey.GetValue(StartupConfiguredValue) is not null)
        {
            return;
        }

        SetStartupEnabled(true);
        appKey.SetValue(StartupConfiguredValue, 1, RegistryValueKind.DWord);
    }

    public bool IsStartupEnabled()
    {
        using RegistryKey? runKey = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
        return runKey?.GetValue(AppName) is string value && value.Length > 0;
    }

    public void SetStartupEnabled(bool enabled)
    {
        using RegistryKey runKey = Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true);
        if (enabled)
        {
            runKey.SetValue(AppName, Quote(_executablePath), RegistryValueKind.String);
        }
        else
        {
            runKey.DeleteValue(AppName, throwOnMissingValue: false);
        }

        using RegistryKey appKey = Registry.CurrentUser.CreateSubKey(AppKeyPath, writable: true);
        appKey.SetValue(StartupConfiguredValue, 1, RegistryValueKind.DWord);
    }

    private static string Quote(string path) => $"\"{path}\"";
}
