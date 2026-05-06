# HealthReminder

一个极简 macOS 菜单栏健康提醒应用：按正在操作电脑的累计时间，提醒护眼、活动、坐姿、喝水和肩颈放松。用户点击“已完成”后，对应提醒开始下一轮计时。

## 运行

下载 GitHub Releases 中的最新 DMG，打开后把 `HealthReminder.app` 放到 `/Applications`，再启动应用。

如果是从源码本地打包：

```bash
bash Scripts/package_app.sh
open build/HealthReminder.app
```

第一次运行时，macOS 会请求通知权限。允许后，提醒会以系统通知形式出现。

## 行为

- 应用常驻菜单栏，不显示主窗口。
- 所有提醒都按键盘或鼠标活跃使用时间累计。
- 离开电脑超过 60 秒时暂停累计。
- 内置提醒：
  - 眨眼 / 放松眼睛：10 分钟
  - 看远处 / 起身活动：20 分钟
  - 调整坐姿：30 分钟
  - 喝水：45 分钟
  - 放松肩颈：60 分钟
- 到点后必须点击通知或菜单里的“已完成”，对应提醒才会重新开始下一轮。
- 忽略提醒时，对应提醒每 5 分钟重复一次。
- 多个提醒独立计时，完成其中一个不会重置其他提醒。
- 从 `.app` 启动时，会写入用户的 `LaunchAgents`，下次登录后自动启动。

## 开发

```bash
swift build
swift test
```

打包产物位于 `build/HealthReminder.app`。

## 发布

```bash
bash Scripts/package_app.sh
mkdir -p release
hdiutil create -volname HealthReminder -srcfolder build/HealthReminder.app -ov -format UDZO release/HealthReminder-0.2.0.dmg
```

发布新版本时，确认 `Scripts/package_app.sh` 中的版本号、Git tag、DMG 文件名和 GitHub Release 版本一致。
