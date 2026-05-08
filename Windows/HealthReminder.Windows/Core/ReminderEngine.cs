namespace HealthReminder.WindowsApp.Core;

public enum ReminderEngineState
{
    Tracking,
    PausedByIdle
}

public sealed record ReminderDefinition(
    string Id,
    string Title,
    string Body,
    TimeSpan Interval
);

public sealed record ReminderProgress(
    ReminderDefinition Definition,
    TimeSpan ElapsedActiveTime,
    ReminderEngineState State
)
{
    public TimeSpan RemainingActiveTime =>
        Definition.Interval - ElapsedActiveTime > TimeSpan.Zero
            ? Definition.Interval - ElapsedActiveTime
            : TimeSpan.Zero;
}

public sealed record ReminderTickResult(IReadOnlyList<ReminderDefinition> RemindersToSend)
{
    public bool ShouldSendReminder => RemindersToSend.Count > 0;
}

public sealed class ReminderEngine
{
    private readonly List<ReminderRecord> _records;

    public ReminderEngine(
        IReadOnlyList<ReminderDefinition> reminders,
        TimeSpan idleThreshold,
        TimeSpan tickInterval
    )
    {
        if (reminders.Select(reminder => reminder.Id).Distinct().Count() != reminders.Count)
        {
            throw new ArgumentException("Reminder IDs must be unique.", nameof(reminders));
        }

        IdleThreshold = idleThreshold;
        TickInterval = tickInterval;
        State = ReminderEngineState.Tracking;
        _records = reminders.Select(reminder => new ReminderRecord(reminder)).ToList();
    }

    public TimeSpan IdleThreshold { get; }
    public TimeSpan TickInterval { get; }
    public ReminderEngineState State { get; private set; }

    public IReadOnlyList<ReminderProgress> Reminders =>
        _records.Select(record => record.Progress).ToList();

    public ReminderProgress? NextReminder =>
        Reminders
            .Where(progress => progress.State == ReminderEngineState.Tracking)
            .MinBy(progress => progress.RemainingActiveTime);

    public ReminderProgress? ProgressFor(string reminderId) =>
        _records.FirstOrDefault(record => record.Definition.Id == reminderId)?.Progress;

    public ReminderTickResult Tick(TimeSpan idleTime)
    {
        if (idleTime >= IdleThreshold)
        {
            State = ReminderEngineState.PausedByIdle;
            return new ReminderTickResult([]);
        }

        List<ReminderDefinition> remindersToSend = [];

        foreach (ReminderRecord record in _records)
        {
            ReminderDefinition? reminder = record.Tick(TickInterval);
            if (reminder is not null)
            {
                remindersToSend.Add(reminder);
            }
        }

        State = ReminderEngineState.Tracking;
        return new ReminderTickResult(remindersToSend);
    }

    private sealed class ReminderRecord
    {
        public ReminderRecord(ReminderDefinition definition)
        {
            Definition = definition;
            ElapsedActiveTime = TimeSpan.Zero;
            State = ReminderEngineState.Tracking;
        }

        public ReminderDefinition Definition { get; }
        public TimeSpan ElapsedActiveTime { get; private set; }
        public ReminderEngineState State { get; private set; }

        public ReminderProgress Progress =>
            new(Definition, ElapsedActiveTime, State);

        public ReminderDefinition? Tick(TimeSpan tickInterval)
        {
            State = ReminderEngineState.Tracking;
            ElapsedActiveTime += tickInterval;

            if (ElapsedActiveTime < Definition.Interval)
            {
                return null;
            }

            Reset();
            return Definition;
        }

        private void Reset()
        {
            ElapsedActiveTime = TimeSpan.Zero;
            State = ReminderEngineState.Tracking;
        }
    }
}
