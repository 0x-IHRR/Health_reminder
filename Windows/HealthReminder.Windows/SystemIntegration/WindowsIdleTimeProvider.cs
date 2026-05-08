using System.Runtime.InteropServices;

namespace HealthReminder.WindowsApp.SystemIntegration;

public sealed class WindowsIdleTimeProvider : IIdleTimeProvider
{
    public TimeSpan GetIdleTime()
    {
        LASTINPUTINFO inputInfo = new()
        {
            cbSize = (uint)Marshal.SizeOf<LASTINPUTINFO>()
        };

        if (!GetLastInputInfo(ref inputInfo))
        {
            return TimeSpan.Zero;
        }

        uint currentTick = unchecked((uint)Environment.TickCount);
        uint elapsedMilliseconds = currentTick - inputInfo.dwTime;
        return TimeSpan.FromMilliseconds(elapsedMilliseconds);
    }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO
    {
        public uint cbSize;
        public uint dwTime;
    }
}
