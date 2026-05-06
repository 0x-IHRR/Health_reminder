# HealthReminder

一个极简 macOS 菜单栏健康提醒应用：持续活跃使用电脑 20 分钟后，提醒看远处、站起来动一下。用户点击“已休息”后开始下一轮计时。

## 运行

```bash
bash Scripts/package_app.sh
open build/HealthReminder.app
```

第一次运行时，macOS 会请求通知权限。允许后，提醒会以系统通知形式出现。

## 行为

- 应用常驻菜单栏，不显示主窗口。
- 键盘或鼠标持续活跃使用累计 20 分钟后提醒。
- 离开电脑超过 60 秒时暂停累计。
- 到点后必须点击通知或菜单里的“已休息”，才会重新开始下一轮。
- 忽略提醒时，每 5 分钟重复提醒一次。
- 从 `.app` 启动时，会写入用户的 `LaunchAgents`，下次登录后自动启动。

## 开发

```bash
swift build
swift test
```

打包产物位于 `build/HealthReminder.app`。
