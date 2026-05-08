using HealthReminder.WindowsApp.Core;
using HealthReminder.WindowsApp.SystemIntegration;
using System.Drawing;
using System.Windows.Forms;

namespace HealthReminder.WindowsApp.Tray;

public sealed class HealthReminderApplicationContext : ApplicationContext
{
    private static readonly IReadOnlyList<ReminderDefinition> ReminderDefinitions =
    [
        new(
            "movement-break",
            "放松眼睛，活动一下",
            "看一下远处，站起来动一动。",
            TimeSpan.FromMinutes(30)
        ),
        new(
            "water",
            "喝水",
            "喝几口水，别等口渴了再喝。",
            TimeSpan.FromMinutes(60)
        ),
        new(
            "posture-relax",
            "调整坐姿，放松肩颈",
            "坐直一点，转转脖子，活动一下肩膀。",
            TimeSpan.FromMinutes(90)
        )
    ];

    private static readonly TimeSpan IdleThreshold = TimeSpan.FromSeconds(60);
    private static readonly TimeSpan TickInterval = TimeSpan.FromSeconds(1);

    private readonly IIdleTimeProvider _idleTimeProvider;
    private readonly IStartupManager _startupManager;
    private readonly ReminderEngine _reminderEngine;
    private readonly NotifyIcon _notifyIcon;
    private readonly ToolStripMenuItem _statusItem;
    private readonly ToolStripMenuItem _startupItem;
    private readonly System.Windows.Forms.Timer _timer;

    public HealthReminderApplicationContext(
        IIdleTimeProvider idleTimeProvider,
        IStartupManager startupManager
    )
    {
        _idleTimeProvider = idleTimeProvider;
        _startupManager = startupManager;
        _reminderEngine = new ReminderEngine(ReminderDefinitions, IdleThreshold, TickInterval);

        _startupManager.EnableOnFirstRun();

        _statusItem = new ToolStripMenuItem("计时中")
        {
            Enabled = false
        };
        _startupItem = new ToolStripMenuItem("开机自启")
        {
            Checked = _startupManager.IsStartupEnabled(),
            CheckOnClick = false
        };
        _startupItem.Click += ToggleStartup;

        ToolStripMenuItem quitItem = new("退出");
        quitItem.Click += (_, _) => ExitThread();

        ContextMenuStrip menu = new();
        menu.Items.Add(_statusItem);
        menu.Items.Add(_startupItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(quitItem);

        _notifyIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "HealthReminder",
            ContextMenuStrip = menu,
            Visible = true
        };

        _timer = new System.Windows.Forms.Timer
        {
            Interval = (int)TickInterval.TotalMilliseconds
        };
        _timer.Tick += (_, _) => Tick();
        _timer.Start();

        UpdateStatus();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _timer.Dispose();
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }

        base.Dispose(disposing);
    }

    private void Tick()
    {
        ReminderTickResult result = _reminderEngine.Tick(_idleTimeProvider.GetIdleTime());

        foreach (ReminderDefinition reminder in result.RemindersToSend)
        {
            ShowReminder(reminder);
        }

        UpdateStatus();
    }

    private void ShowReminder(ReminderDefinition reminder)
    {
        _notifyIcon.BalloonTipTitle = reminder.Title;
        _notifyIcon.BalloonTipText = reminder.Body;
        _notifyIcon.BalloonTipIcon = ToolTipIcon.Info;
        _notifyIcon.ShowBalloonTip(10_000);
    }

    private void UpdateStatus()
    {
        if (_reminderEngine.State == ReminderEngineState.PausedByIdle)
        {
            _statusItem.Text = "已离开，计时暂停";
            _notifyIcon.Text = "HealthReminder - 已暂停";
            return;
        }

        ReminderProgress? nextReminder = _reminderEngine.NextReminder;
        if (nextReminder is null)
        {
            _statusItem.Text = "计时中";
            _notifyIcon.Text = "HealthReminder";
            return;
        }

        string text = $"下一项：{nextReminder.Definition.Title}，约 {MinutesText(nextReminder.RemainingActiveTime)}后";
        _statusItem.Text = text;
        _notifyIcon.Text = text.Length <= 63 ? text : "HealthReminder - 计时中";
    }

    private void ToggleStartup(object? sender, EventArgs eventArgs)
    {
        bool enabled = !_startupManager.IsStartupEnabled();
        _startupManager.SetStartupEnabled(enabled);
        _startupItem.Checked = enabled;
    }

    private static string MinutesText(TimeSpan remainingTime)
    {
        int remainingMinutes = Math.Max(1, (int)Math.Ceiling(remainingTime.TotalMinutes));
        return $"{remainingMinutes} 分钟";
    }
}
