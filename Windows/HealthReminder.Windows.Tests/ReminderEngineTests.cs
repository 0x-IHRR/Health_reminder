using HealthReminder.WindowsApp.Core;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace HealthReminder.Windows.Tests;

[TestClass]
public sealed class ReminderEngineTests
{
    [TestMethod]
    public void ActiveUseTriggersEachReminderAtConfiguredIntervalAndAutoResetsIt()
    {
        ReminderEngine engine = MakeEngine();

        CollectionAssert.AreEqual(Array.Empty<string>(), engine.Tick(TimeSpan.Zero).RemindersToSend.Select(reminder => reminder.Id).ToArray());
        CollectionAssert.AreEqual(Array.Empty<string>(), engine.Tick(TimeSpan.Zero).RemindersToSend.Select(reminder => reminder.Id).ToArray());

        ReminderTickResult firstResult = engine.Tick(TimeSpan.Zero);

        CollectionAssert.AreEqual(new[] { "movement" }, firstResult.RemindersToSend.Select(reminder => reminder.Id).ToArray());
        Assert.AreEqual(ReminderEngineState.Tracking, engine.State);
        Assert.AreEqual(TimeSpan.Zero, engine.ProgressFor("movement")?.ElapsedActiveTime);
        Assert.AreEqual(TimeSpan.FromSeconds(3), engine.ProgressFor("water")?.ElapsedActiveTime);

        ReminderTickResult secondResult = engine.Tick(TimeSpan.Zero);

        CollectionAssert.AreEqual(new[] { "water" }, secondResult.RemindersToSend.Select(reminder => reminder.Id).ToArray());
        Assert.AreEqual(TimeSpan.Zero, engine.ProgressFor("water")?.ElapsedActiveTime);
        Assert.AreEqual(TimeSpan.FromSeconds(1), engine.ProgressFor("movement")?.ElapsedActiveTime);
    }

    [TestMethod]
    public void IdleUsePausesAllRemindersWithoutIncreasingActiveTime()
    {
        ReminderEngine engine = MakeEngine();

        _ = engine.Tick(TimeSpan.Zero);
        _ = engine.Tick(TimeSpan.FromSeconds(5));

        Assert.AreEqual(TimeSpan.FromSeconds(2), engine.ProgressFor("movement")?.ElapsedActiveTime);
        Assert.AreEqual(TimeSpan.FromSeconds(2), engine.ProgressFor("water")?.ElapsedActiveTime);
        Assert.AreEqual(ReminderEngineState.Tracking, engine.State);

        ReminderTickResult result = engine.Tick(TimeSpan.FromSeconds(60));

        Assert.AreEqual(0, result.RemindersToSend.Count);
        Assert.AreEqual(TimeSpan.FromSeconds(2), engine.ProgressFor("movement")?.ElapsedActiveTime);
        Assert.AreEqual(TimeSpan.FromSeconds(2), engine.ProgressFor("water")?.ElapsedActiveTime);
        Assert.AreEqual(ReminderEngineState.PausedByIdle, engine.State);
    }

    [TestMethod]
    public void AutoResetDoesNotCreateRepeatReminders()
    {
        ReminderEngine engine = MakeEngine();

        for (int index = 0; index < 3; index++)
        {
            _ = engine.Tick(TimeSpan.Zero);
        }

        Assert.AreEqual(TimeSpan.Zero, engine.ProgressFor("movement")?.ElapsedActiveTime);

        CollectionAssert.AreEqual(new[] { "water" }, engine.Tick(TimeSpan.Zero).RemindersToSend.Select(reminder => reminder.Id).ToArray());
        CollectionAssert.AreEqual(Array.Empty<string>(), engine.Tick(TimeSpan.Zero).RemindersToSend.Select(reminder => reminder.Id).ToArray());

        ReminderTickResult nextMovementResult = engine.Tick(TimeSpan.Zero);

        CollectionAssert.AreEqual(new[] { "movement" }, nextMovementResult.RemindersToSend.Select(reminder => reminder.Id).ToArray());
        Assert.AreEqual(ReminderEngineState.Tracking, engine.State);
    }

    [TestMethod]
    public void NextReminderUsesNearestRemainingActiveTime()
    {
        ReminderEngine engine = MakeEngine();

        _ = engine.Tick(TimeSpan.Zero);

        Assert.AreEqual("movement", engine.NextReminder?.Definition.Id);

        for (int index = 0; index < 2; index++)
        {
            _ = engine.Tick(TimeSpan.Zero);
        }

        Assert.AreEqual("water", engine.NextReminder?.Definition.Id);
    }

    [TestMethod]
    public void MultipleRemindersCanTriggerOnTheSameTick()
    {
        ReminderEngine engine = new(
            [
                new ReminderDefinition("movement", "活动", "动一下。", TimeSpan.FromSeconds(3)),
                new ReminderDefinition("posture", "坐姿", "坐直。", TimeSpan.FromSeconds(3))
            ],
            TimeSpan.FromSeconds(60),
            TimeSpan.FromSeconds(1)
        );

        _ = engine.Tick(TimeSpan.Zero);
        _ = engine.Tick(TimeSpan.Zero);

        CollectionAssert.AreEqual(
            new[] { "movement", "posture" },
            engine.Tick(TimeSpan.Zero).RemindersToSend.Select(reminder => reminder.Id).ToArray()
        );
        Assert.AreEqual(TimeSpan.Zero, engine.ProgressFor("movement")?.ElapsedActiveTime);
        Assert.AreEqual(TimeSpan.Zero, engine.ProgressFor("posture")?.ElapsedActiveTime);
    }

    private static ReminderEngine MakeEngine() =>
        new(
            [
                new ReminderDefinition("movement", "放松眼睛，活动一下", "看一下远处，站起来动一动。", TimeSpan.FromSeconds(3)),
                new ReminderDefinition("water", "喝水", "喝几口水。", TimeSpan.FromSeconds(4))
            ],
            TimeSpan.FromSeconds(60),
            TimeSpan.FromSeconds(1)
        );
}
