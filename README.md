# HealthReminder

一个极简健康提醒应用：按正在操作电脑的累计时间，轻量提醒护眼活动、喝水和坐姿肩颈放松。提醒发出后会自动进入下一轮计时。

目前支持：

- macOS 菜单栏版本
- Windows 系统托盘版本

## 运行

### macOS

下载 GitHub Releases 中的最新 DMG，打开后把 `HealthReminder.app` 放到 `/Applications`，再启动应用。

如果是从源码本地打包：

```bash
bash Scripts/package_app.sh
open build/HealthReminder.app
```

### Windows

下载 GitHub Releases 中的 `HealthReminder-<version>-win-x64.zip`，解压后运行 `HealthReminder.exe`。

Windows 版是自包含包，不需要额外安装 .NET。第一次运行后会默认开启当前用户的开机自启，可在托盘菜单里关闭。

## 行为

- macOS 版常驻菜单栏，Windows 版常驻系统托盘，不显示主窗口。
- 所有提醒都按键盘或鼠标活跃使用时间累计。
- 离开电脑超过 60 秒时暂停累计。
- macOS 版提醒以屏幕中上方暗色浮层显示，文字居中，自动淡出，不需要点击确认。
- macOS 浮层出现时会播放短暂轻粒子点阵重构动画，退出时粒子向四周散开，阅读阶段保持安静。
- 内置提醒：
  - 放松眼睛 / 起身活动：30 分钟
  - 喝水：60 分钟
  - 调整坐姿 / 放松肩颈：90 分钟
- 提醒发出后自动进入下一轮，不需要手动确认。
- 多个提醒独立计时，其中一个提醒触发不会重置其他提醒。
- macOS 版可以设置一个当前主线任务，按 15 分钟活跃时间召回；完成后会停止召回，直到重新设置任务。
- macOS 版可以从 Obsidian Kanban 的 `## 收件箱` 中只读选择未完成任务，不会修改 Obsidian 文件。
- 从 `.app` 启动时，会写入用户的 `LaunchAgents`，下次登录后自动启动。
- Windows 版会写入当前用户的 `Run` 启动项，下次登录后自动启动。

## macOS 本地配置

macOS 版可以读取本地配置文件覆盖默认参数：

```bash
mkdir -p ~/.config/HealthReminder
cp config.example.env ~/.config/HealthReminder/config.env
```

配置文件只支持简单的 `KEY=value`，不支持 `15 * 60` 这类表达式。非法值会被忽略并回退到默认值。常用参数包括：

- `FOCUS_REMINDER_INTERVAL_SECONDS`：主线任务召回间隔。
- `KANBAN_PATH`：Obsidian Kanban 文件路径。
- `KANBAN_INBOX_SECTION`：候选任务来源 section，默认 `收件箱`。
- `OVERLAY_THEME`：浮层视觉主题，默认 `dark_neon`。
- `OVERLAY_TEXT_ALIGNMENT`：浮层文字对齐，默认 `center`。
- `OVERLAY_POSITION`：浮层位置，默认 `upper_center`。
- `OVERLAY_VERTICAL_OFFSET_RATIO`：浮层相对屏幕中心向上的偏移比例，默认 `0.18`。
- `OVERLAY_PARTICLE_STYLE`：浮层粒子效果，支持 `reconstruct`、`light` 或 `off`。
- `OVERLAY_PARTICLE_COUNT`、`OVERLAY_PARTICLE_CANVAS_PADDING`：粒子数量和卡片外侧粒子画布范围。
- `OVERLAY_DISPLAY_SECONDS`、`OVERLAY_WIDTH`、`OVERLAY_HEIGHT`：浮层显示时间和尺寸。

## 开发

```bash
swift build
swift test
```

打包产物位于 `build/HealthReminder.app`。

Windows 测试和打包在 Windows 环境运行：

```powershell
dotnet test Windows/HealthReminder.Windows.Tests/HealthReminder.Windows.Tests.csproj --configuration Release
./Scripts/package_windows.ps1
```

## 发布

```bash
bash Scripts/package_app.sh
mkdir -p release
VERSION="$(cat VERSION)"
hdiutil create -volname HealthReminder -srcfolder build/HealthReminder.app -ov -format UDZO "release/HealthReminder-${VERSION}.dmg"
```

发布新版本时，更新 `VERSION`，创建同版本 Git tag。推送 `v<version>` tag 后，GitHub Actions 会生成 macOS DMG 和 Windows x64 ZIP，并创建 GitHub Release。
