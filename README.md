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
- macOS 版提醒以屏幕中上方浮层显示，文字居中，自动淡出，不需要点击确认。
- macOS 浮层支持 Light/Dark 主题、文字风格、字号和粒子效果配置；出现时可播放短暂粒子凝聚动画，退出时粒子散开，阅读阶段保持安静。
- 内置健康提醒槽位：
  - 休息 / 放松眼睛：30 分钟，默认开启。
  - 喝水：60 分钟，默认开启。
  - 调整坐姿 / 放松肩颈：90 分钟，默认开启。
  - 吃药：240 分钟，默认关闭。
- macOS 版可以在 `设置...` 里编辑外观、健康提醒、Kanban 来源和关于页信息；健康提醒也可以用 `+` 添加自定义项。
- 提醒发出后自动进入下一轮，不需要手动确认。
- 多个提醒独立计时，其中一个提醒触发不会重置其他提醒。
- 同一 tick 内多个提醒同时触发时，macOS 版会合并成一张浮层：主线任务优先，健康提醒压缩为 `顺手：...`。
- macOS 版可以设置一个当前主线任务，按 15 分钟活跃时间召回；完成后会停止召回，直到重新设置任务。
- macOS 版可以从 Obsidian Kanban Markdown 中只读选择未完成任务；候选 section 和文件路径可配置，不会修改 Obsidian 文件。
- 从 `.app` 启动时，会写入用户的 `LaunchAgents`，下次登录后自动启动。
- Windows 版会写入当前用户的 `Run` 启动项，下次登录后自动启动。

## macOS 本地配置

macOS 版可以读取本地配置文件覆盖默认参数：

```bash
mkdir -p ~/.config/HealthReminder
cp config.example.env ~/.config/HealthReminder/config.env
```

配置文件只支持简单的 `KEY=value`，不支持 `15 * 60` 这类表达式。非法值会被忽略并回退到默认值。常用参数包括：

也可以从 macOS 菜单栏打开 `设置...` 调整浮层外观、健康提醒列表、Kanban 来源和关于页信息。设置窗口会写入本地配置文件，并在重启 HealthReminder 后生效；外观页会即时显示静态预览，健康提醒页的“测试提醒”只预览浮层，不影响计时。

- `FOCUS_REMINDER_INTERVAL_SECONDS`：主线任务召回间隔。
- `KANBAN_PATH`：Obsidian Kanban 文件路径。
- `KANBAN_INBOX_SECTION`：候选任务来源 section，默认 `收件箱`；留空时读取整个文件中的未完成任务。
- `HEALTH_REMINDERS_ENABLED`：健康提醒总开关；关闭后不影响主线任务召回。
- `HEALTH_REMINDER_IDS`：健康提醒列表顺序，例如 `rest,water,posture,medicine,custom_1`。
- `HEALTH_REMINDER_<SLOT>_ENABLED`：单条健康提醒开关。
- `HEALTH_REMINDER_<SLOT>_TITLE`、`HEALTH_REMINDER_<SLOT>_BODY`：健康提醒标题和正文，`<SLOT>` 支持内置 `REST`、`WATER`、`POSTURE`、`MEDICINE`，也支持 `CUSTOM_1` 这类自定义 ID。
- `HEALTH_REMINDER_<SLOT>_INTERVAL_SECONDS`：健康提醒间隔秒数。
- 旧的 `HEALTH_MOVEMENT_INTERVAL_SECONDS`、`HEALTH_WATER_INTERVAL_SECONDS`、`HEALTH_POSTURE_INTERVAL_SECONDS` 仍会读取；设置窗口保存时会写入新的 `HEALTH_REMINDER_*` 键。
- `OVERLAY_THEME`：浮层视觉主题，支持 `dark_particle`、`light_particle`；旧值 `dark_neon` 会映射到 `dark_particle`。
- `OVERLAY_TEXT_ALIGNMENT`：浮层文字对齐，默认 `center`。
- `OVERLAY_TEXT_STYLE`：浮层文字风格，支持 `classic`、`prism`、`aurora`、`warm`，默认 `classic`。
- `OVERLAY_TEXT_SIZE`：浮层文字大小，支持 `small`、`medium`、`large`，默认 `medium`。
- `OVERLAY_POSITION`：浮层位置，默认 `upper_center`。
- `OVERLAY_VERTICAL_OFFSET_RATIO`：浮层相对屏幕中心向上的偏移比例，默认 `0.18`。
- `OVERLAY_BACKDROP_STYLE`：提醒出现时的专注暗幕，支持 `off`、`dim`、`dim_glow`，默认 `off`；这是视觉遮罩，不会调整系统屏幕亮度，也不会锁定鼠标键盘。
- `OVERLAY_BACKDROP_OPACITY`：专注暗幕透明度，支持 `0.2`-`0.9`，默认 `0.72`。
- `OVERLAY_PARTICLE_STYLE`：浮层粒子效果，支持 `reconstruct`、`light` 或 `off`，macOS 版由 Vortex 粒子系统渲染。
- `OVERLAY_PARTICLE_COUNT`、`OVERLAY_PARTICLE_CANVAS_PADDING`：粒子数量和卡片外侧粒子画布范围。
- `OVERLAY_DISPLAY_SECONDS`：全局浮层显示时间，支持 2-12 秒。
- `OVERLAY_WIDTH`、`OVERLAY_HEIGHT`：浮层尺寸。
- `ABOUT_DEVELOPER_NAME`、`ABOUT_WEBSITE_URL`、`ABOUT_EMAIL`、`ABOUT_GITHUB_URL`、`ABOUT_COMMUNITY_URL`、`ABOUT_FEEDBACK_URL`：关于页开发者信息，空值不会展示。

## 开发

```bash
swift build
swift test
```

打包产物位于 `build/HealthReminder.app`。

macOS 浮层使用 vendored `Vendor/Vortex` 粒子库。上游 Vortex 为 MIT 许可；本仓库保留其 `LICENSE`。App 图标和菜单栏 template 图标位于 `Sources/HealthReminder/Resources/`，打包脚本会生成 `AppIcon.icns` 并复制运行时资源。

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
当前最新版本：`v0.5.0`。
