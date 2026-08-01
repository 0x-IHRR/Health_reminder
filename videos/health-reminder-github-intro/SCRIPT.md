# Script

电脑用久了，最容易忘记的不是工作，是休息。

HealthReminder 是一个极简健康提醒工具。macOS 健康提醒默认按屏幕亮着的时间累计，也可以切换为键盘和鼠标活跃时间；Windows 版按键鼠活跃时间累计，不是无条件死盯墙上的时间。

它支持 macOS 菜单栏和 Windows 系统托盘，没有主窗口。macOS 提醒出现时，蓝猫会抱着程序渲染的醒目黄色卡片从下方弹入。

内置三类提醒：三十分钟放松眼睛，六十分钟喝水，九十分钟调整坐姿。

屏幕睡眠时会暂停默认计时；使用键鼠活跃模式时，离开电脑超过六十秒也会暂停。提醒发出后自动进入下一轮，多个提醒独立计时。

安装也很简单：macOS 下载 DMG 放进 Applications；Windows 下载 x64 压缩包，解压运行 exe。

开发者可以用 Swift build 和 Swift test 验证；推送版本 tag 后，GitHub Actions 会生成 DMG 和 Windows ZIP。

HealthReminder，把健康提醒做成一个安静的小工具。
