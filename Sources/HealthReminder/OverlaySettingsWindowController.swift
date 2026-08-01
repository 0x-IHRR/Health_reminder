import AppKit
import HealthReminderCore
import SwiftUI
import UniformTypeIdentifiers

final class OverlaySettingsWindowController: NSWindowController {
    private static let windowSize = NSSize(width: 820, height: 560)

    private let configURL: URL
    private let testReminderHandler: (String, String) -> Void
    private let tabView = NSTabView()
    private let settingsSegmentedControl = NSSegmentedControl(
        labels: ["外观", "健康提醒", "Kanban", "关于"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let themePopUp = NSPopUpButton()
    private let textStylePopUp = NSPopUpButton()
    private let textSizePopUp = NSPopUpButton()
    private let displaySecondsField = NSTextField()
    private let backdropStylePopUp = NSPopUpButton()
    private let particleStylePopUp = NSPopUpButton()
    private lazy var overlayPreviewHostingView = NSHostingView(
        rootView: ReminderOverlayPreviewView(
            title: "回到主线任务",
            messageBody: "整理今天最重要的一步。",
            configuration: AppConfiguration.defaults.overlay
        )
    )
    private let kanbanPathField = NSTextField()
    private let kanbanSectionField = NSTextField()
    private let kanbanStatusLabel = NSTextField(labelWithString: "")
    private let aboutDeveloperNameField = NSTextField()
    private let aboutWebsiteURLField = NSTextField()
    private let aboutEmailField = NSTextField()
    private let aboutGithubURLField = NSTextField()
    private let aboutCommunityURLField = NSTextField()
    private let aboutFeedbackURLField = NSTextField()
    private let healthRemindersEnabledButton = NSButton(checkboxWithTitle: "启用健康提醒", target: nil, action: nil)
    private let healthReminderCountingModePopUp = NSPopUpButton()
    private let healthReminderRowsStack = NSStackView()
    private var healthReminderControls: [HealthReminderControls] = []

    init(configURL: URL, testReminderHandler: @escaping (String, String) -> Void) {
        self.configURL = configURL
        self.testReminderHandler = testReminderHandler

        let contentView = NSView(frame: NSRect(origin: .zero, size: Self.windowSize))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.windowSize.width),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.windowSize.height)
        ])
        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HealthReminder 设置"
        window.contentView = contentView
        window.minSize = Self.windowSize
        window.contentMinSize = Self.windowSize
        window.maxSize = NSSize(width: 1200, height: 900)
        window.contentMaxSize = NSSize(width: 1200, height: 900)
        window.isReleasedWhenClosed = false
        window.level = .statusBar

        super.init(window: window)
        configureContentView(contentView)
        loadCurrentValues()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        loadCurrentValues()
        resizeAndCenterWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resizeAndCenterWindow() {
        guard let window else {
            return
        }

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = NSRect(
            x: visibleFrame.midX - Self.windowSize.width / 2,
            y: visibleFrame.midY - Self.windowSize.height / 2,
            width: Self.windowSize.width,
            height: Self.windowSize.height
        )
        window.setFrame(frame, display: true)
        window.setContentSize(Self.windowSize)
        window.contentView?.frame = NSRect(origin: .zero, size: Self.windowSize)
    }

    private func configureContentView(_ contentView: NSView) {
        settingsSegmentedControl.target = self
        settingsSegmentedControl.action = #selector(selectSettingsPage)
        settingsSegmentedControl.selectedSegment = 0

        tabView.tabViewType = .noTabsNoBorder
        let appearanceItem = NSTabViewItem(identifier: "appearance")
        appearanceItem.label = "外观"
        appearanceItem.view = makeAppearanceView()

        let healthItem = NSTabViewItem(identifier: "health")
        healthItem.label = "健康提醒"
        healthItem.view = makeHealthReminderView()

        let kanbanItem = NSTabViewItem(identifier: "kanban")
        kanbanItem.label = "Kanban"
        kanbanItem.view = makeKanbanView()

        let aboutItem = NSTabViewItem(identifier: "about")
        aboutItem.label = "关于"
        aboutItem.view = makeAboutView()

        tabView.addTabViewItem(appearanceItem)
        tabView.addTabViewItem(healthItem)
        tabView.addTabViewItem(kanbanItem)
        tabView.addTabViewItem(aboutItem)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [cancelButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 10

        for view in [settingsSegmentedControl, tabView, buttonStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            settingsSegmentedControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            settingsSegmentedControl.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            tabView.topAnchor.constraint(equalTo: settingsSegmentedControl.bottomAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tabView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -16),

            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func centeredContainer(width: CGFloat, in contentView: NSView) -> NSStackView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .centerX
        container.spacing = 14
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            container.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: width),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])

        return container
    }

    private func pageTitle(_ title: String, help: String) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.alignment = .center

        let helpLabel = NSTextField(wrappingLabelWithString: help)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.font = .systemFont(ofSize: 12)
        helpLabel.alignment = .center

        let stack = NSStackView(views: [titleLabel, helpLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        return stack
    }

    private func makeAppearanceView() -> NSView {
        let contentView = NSView()
        let container = centeredContainer(width: 560, in: contentView)
        let titleStack = pageTitle(
            "外观",
            help: "保存后会写入本地配置文件；重启 HealthReminder 后生效。下方预览会随选择即时变化。"
        )

        configure(
            themePopUp,
            items: [
                ("alert_yellow", "醒目黄色"),
                ("dark_particle", "深色粒子"),
                ("light_particle", "浅色粒子")
            ]
        )
        configure(
            textStylePopUp,
            items: [
                ("classic", "Classic 经典"),
                ("prism", "Prism 蓝紫"),
                ("aurora", "Aurora 极光"),
                ("warm", "Warm 暖色")
            ]
        )
        configure(
            textSizePopUp,
            items: [
                ("small", "Small 小"),
                ("medium", "Medium 中"),
                ("large", "Large 大")
            ]
        )
        configure(
            particleStylePopUp,
            items: [
                ("reconstruct", "粒子凝聚"),
                ("off", "关闭粒子")
            ]
        )
        configure(
            backdropStylePopUp,
            items: [
                ("off", "关闭"),
                ("dim", "暗幕"),
                ("dim_glow", "暗幕聚焦")
            ]
        )
        displaySecondsField.placeholderString = "2-12"
        displaySecondsField.alignment = .right
        for control in [themePopUp, textStylePopUp, textSizePopUp, backdropStylePopUp, particleStylePopUp] {
            control.target = self
            control.action = #selector(updateOverlayPreview)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateOverlayPreview),
            name: NSControl.textDidChangeNotification,
            object: displaySecondsField
        )

        let form = NSGridView(views: [
            [label("主题"), themePopUp],
            [label("文字风格"), textStylePopUp],
            [label("字号"), textSizePopUp],
            [label("显示时间"), displaySecondsField],
            [label("专注暗幕"), backdropStylePopUp],
            [label("粒子效果"), particleStylePopUp]
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).width = 230
        form.rowSpacing = 12

        let displayHelpLabel = NSTextField(labelWithString: "单位为秒，支持 2-12。")
        displayHelpLabel.textColor = .secondaryLabelColor
        displayHelpLabel.font = .systemFont(ofSize: 12)
        displayHelpLabel.alignment = .center

        overlayPreviewHostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(titleStack)
        container.addArrangedSubview(overlayPreviewHostingView)
        container.addArrangedSubview(form)
        container.addArrangedSubview(displayHelpLabel)

        NSLayoutConstraint.activate([
            displaySecondsField.widthAnchor.constraint(equalToConstant: 72),
            overlayPreviewHostingView.widthAnchor.constraint(equalToConstant: 484),
            overlayPreviewHostingView.heightAnchor.constraint(equalToConstant: 196)
        ])

        return contentView
    }

    private func makeHealthReminderView() -> NSView {
        let contentView = NSView()
        let container = centeredContainer(width: 700, in: contentView)
        let titleStack = pageTitle(
            "健康提醒",
            help: "健康提醒和主线任务独立计时；这里可以添加、关闭或删除健康提醒。"
        )
        configure(
            healthReminderCountingModePopUp,
            items: [
                ("screen_awake", "屏幕亮着时计时"),
                ("input_active", "键鼠活跃时计时")
            ]
        )
        let countingModeForm = NSGridView(views: [
            [label("计时方式"), healthReminderCountingModePopUp]
        ])
        countingModeForm.column(at: 0).xPlacement = .trailing
        countingModeForm.column(at: 1).width = 220

        healthReminderRowsStack.orientation = .vertical
        healthReminderRowsStack.alignment = .leading
        healthReminderRowsStack.spacing = 8

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let scrollDocumentView = FlippedView()
        scrollDocumentView.frame = NSRect(x: 0, y: 0, width: 680, height: 240)
        scrollDocumentView.translatesAutoresizingMaskIntoConstraints = false
        healthReminderRowsStack.translatesAutoresizingMaskIntoConstraints = false
        scrollDocumentView.addSubview(healthReminderRowsStack)
        scrollView.documentView = scrollDocumentView

        let addButton = NSButton(image: plusImage(), target: self, action: #selector(addCustomReminder))
        addButton.bezelStyle = .texturedRounded
        addButton.toolTip = "添加健康提醒"

        let testButton = NSButton(title: "测试提醒", target: self, action: #selector(testReminder))
        testButton.bezelStyle = .rounded

        let actionStack = NSStackView(views: [addButton, testButton])
        actionStack.orientation = .horizontal
        actionStack.alignment = .centerY
        actionStack.spacing = 10

        let intervalUnitLabel = NSTextField(labelWithString: "间隔单位为分钟；保存后重启生效。")
        intervalUnitLabel.textColor = .secondaryLabelColor
        intervalUnitLabel.font = .systemFont(ofSize: 12)

        let footerStack = NSStackView(views: [actionStack, intervalUnitLabel])
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.spacing = 14

        for view in [titleStack, healthRemindersEnabledButton, countingModeForm, scrollView, footerStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addArrangedSubview(view)
        }

        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 700),
            scrollView.heightAnchor.constraint(equalToConstant: 210),

            scrollDocumentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            healthReminderRowsStack.topAnchor.constraint(equalTo: scrollDocumentView.topAnchor),
            healthReminderRowsStack.leadingAnchor.constraint(equalTo: scrollDocumentView.leadingAnchor),
            healthReminderRowsStack.trailingAnchor.constraint(lessThanOrEqualTo: scrollDocumentView.trailingAnchor),
            healthReminderRowsStack.bottomAnchor.constraint(lessThanOrEqualTo: scrollDocumentView.bottomAnchor)
        ])

        return contentView
    }

    private func makeKanbanView() -> NSView {
        let contentView = NSView()
        let container = centeredContainer(width: 640, in: contentView)
        let titleStack = pageTitle(
            "Kanban",
            help: "主线任务候选只从 Obsidian Kanban Markdown 里只读读取；这里可以换文件路径和收件箱 section。"
        )

        kanbanPathField.placeholderString = "/path/to/Kanban.md"
        kanbanSectionField.placeholderString = "收件箱；留空则读取全文件未完成任务"

        let chooseButton = NSButton(title: "选择文件...", target: self, action: #selector(chooseKanbanFile))
        chooseButton.bezelStyle = .rounded

        let testButton = NSButton(title: "测试读取", target: self, action: #selector(testKanbanRead))
        testButton.bezelStyle = .rounded

        let pathStack = NSStackView(views: [kanbanPathField, chooseButton])
        pathStack.orientation = .horizontal
        pathStack.alignment = .centerY
        pathStack.spacing = 8

        let form = NSGridView(views: [
            [label("Kanban 文件"), pathStack],
            [label("候选 section"), kanbanSectionField]
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).width = 500
        form.rowSpacing = 12

        kanbanStatusLabel.textColor = .secondaryLabelColor
        kanbanStatusLabel.font = .systemFont(ofSize: 12)
        kanbanStatusLabel.alignment = .center
        kanbanStatusLabel.lineBreakMode = .byTruncatingTail

        let actionStack = NSStackView(views: [testButton])
        actionStack.orientation = .horizontal
        actionStack.alignment = .centerY

        for view in [titleStack, form, actionStack, kanbanStatusLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addArrangedSubview(view)
        }

        NSLayoutConstraint.activate([
            kanbanPathField.widthAnchor.constraint(equalToConstant: 382),
            kanbanSectionField.widthAnchor.constraint(equalToConstant: 500),
            kanbanStatusLabel.widthAnchor.constraint(equalToConstant: 560)
        ])

        return contentView
    }

    private func makeAboutView() -> NSView {
        let contentView = NSView()
        let container = centeredContainer(width: 560, in: contentView)

        let iconImageView = NSImageView()
        iconImageView.image = NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: "HealthReminder")
        iconImageView.imageScaling = .scaleProportionallyUpOrDown

        let nameLabel = NSTextField(labelWithString: "HealthReminder")
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: "v\(appVersionText())")
        versionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let headerStack = NSStackView(views: [iconImageView, nameLabel, versionLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 8

        for field in [
            aboutDeveloperNameField,
            aboutWebsiteURLField,
            aboutEmailField,
            aboutGithubURLField,
            aboutCommunityURLField,
            aboutFeedbackURLField
        ] {
            field.placeholderString = "留空则不显示"
        }

        let form = NSGridView(views: [
            [label("开发者"), aboutDeveloperNameField],
            [label("官网"), aboutWebsiteURLField],
            [label("邮箱"), aboutEmailField],
            [label("GitHub"), aboutGithubURLField],
            [label("社区"), aboutCommunityURLField],
            [label("反馈"), aboutFeedbackURLField]
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).width = 360
        form.rowSpacing = 10

        let helpLabel = NSTextField(
            wrappingLabelWithString: "这些信息会写入本地配置文件；空字段不会在关于页入口中展示，适合你自己发行或别人 fork 后替换。"
        )
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.font = .systemFont(ofSize: 12)
        helpLabel.alignment = .center

        for view in [headerStack, form, helpLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addArrangedSubview(view)
        }

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 76),
            iconImageView.heightAnchor.constraint(equalToConstant: 76)
        ])

        return contentView
    }

    private func configure(_ popUp: NSPopUpButton, items: [(String, String)]) {
        popUp.removeAllItems()

        for item in items {
            popUp.addItem(withTitle: item.1)
            popUp.lastItem?.representedObject = item.0
        }
    }

    private func label(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func headerLabel(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func loadCurrentValues() {
        let configuration = AppConfiguration.load(from: configURL)
        select(themePopUp, representedObject: configuration.overlay.theme)
        select(textStylePopUp, representedObject: configuration.overlay.textStyle)
        select(textSizePopUp, representedObject: configuration.overlay.textSize)
        select(backdropStylePopUp, representedObject: configuration.overlay.backdropStyle)
        select(particleStylePopUp, representedObject: configuration.overlay.particleStyle == "off" ? "off" : "reconstruct")
        displaySecondsField.stringValue = formattedSeconds(configuration.overlay.displaySeconds)
        kanbanPathField.stringValue = configuration.kanbanPath
        kanbanSectionField.stringValue = configuration.kanbanInboxSection
        aboutDeveloperNameField.stringValue = configuration.about.developerName
        aboutWebsiteURLField.stringValue = configuration.about.websiteURL
        aboutEmailField.stringValue = configuration.about.email
        aboutGithubURLField.stringValue = configuration.about.githubURL
        aboutCommunityURLField.stringValue = configuration.about.communityURL
        aboutFeedbackURLField.stringValue = configuration.about.feedbackURL
        healthRemindersEnabledButton.state = configuration.healthRemindersEnabled ? .on : .off
        select(healthReminderCountingModePopUp, representedObject: configuration.healthReminderCountingMode)
        setHealthReminders(configuration.healthReminders)
        updateOverlayPreview()
    }

    private func setHealthReminders(_ reminders: [AppConfiguration.HealthReminderConfiguration]) {
        for view in healthReminderRowsStack.arrangedSubviews {
            healthReminderRowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        healthReminderControls.removeAll()

        healthReminderRowsStack.addArrangedSubview(makeHealthReminderHeaderRow())
        for reminder in reminders {
            addHealthReminderRow(reminder)
        }
    }

    private func addHealthReminderRow(_ reminder: AppConfiguration.HealthReminderConfiguration) {
        let isBuiltIn = isBuiltInHealthReminderID(reminder.id)
        let enabledButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        enabledButton.state = reminder.isEnabled ? .on : .off

        let titleField = NSTextField()
        titleField.placeholderString = "提醒标题"
        titleField.stringValue = reminder.title

        let bodyField = NSTextField()
        bodyField.placeholderString = "提醒正文"
        bodyField.stringValue = reminder.body

        let intervalField = NSTextField()
        intervalField.placeholderString = "分钟"
        intervalField.alignment = .right
        intervalField.stringValue = "\(Int(round(reminder.interval / 60)))"

        let deleteButton = NSButton(image: trashImage(), target: self, action: #selector(deleteCustomReminder(_:)))
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.toolTip = "删除健康提醒"
        deleteButton.identifier = NSUserInterfaceItemIdentifier(reminder.id)
        deleteButton.isHidden = isBuiltIn

        let nameLabel = label(displayName(forHealthReminderID: reminder.id))
        nameLabel.lineBreakMode = .byTruncatingTail

        for view in [nameLabel, titleField, bodyField, intervalField] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            nameLabel.widthAnchor.constraint(equalToConstant: 72),
            titleField.widthAnchor.constraint(equalToConstant: 150),
            bodyField.widthAnchor.constraint(equalToConstant: 280),
            intervalField.widthAnchor.constraint(equalToConstant: 64)
        ])

        let rowStack = NSStackView(views: [
            nameLabel,
            enabledButton,
            titleField,
            bodyField,
            intervalField,
            deleteButton
        ])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10

        let controls = HealthReminderControls(
            id: reminder.id,
            isBuiltIn: isBuiltIn,
            rowView: rowStack,
            enabledButton: enabledButton,
            titleField: titleField,
            bodyField: bodyField,
            intervalField: intervalField
        )
        healthReminderControls.append(controls)
        healthReminderRowsStack.addArrangedSubview(rowStack)
    }

    private func makeHealthReminderHeaderRow() -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = NSStackView(views: [
            headerLabel("项目"),
            headerLabel("启用"),
            headerLabel("标题"),
            headerLabel("正文"),
            headerLabel("间隔"),
            spacer
        ])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10

        NSLayoutConstraint.activate([
            rowStack.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 72),
            rowStack.arrangedSubviews[1].widthAnchor.constraint(equalToConstant: 32),
            rowStack.arrangedSubviews[2].widthAnchor.constraint(equalToConstant: 150),
            rowStack.arrangedSubviews[3].widthAnchor.constraint(equalToConstant: 280),
            rowStack.arrangedSubviews[4].widthAnchor.constraint(equalToConstant: 64),
            spacer.widthAnchor.constraint(equalToConstant: 32)
        ])

        return rowStack
    }

    private func select(_ popUp: NSPopUpButton, representedObject: String) {
        for item in popUp.itemArray where item.representedObject as? String == representedObject {
            popUp.select(item)
            return
        }

        popUp.selectItem(at: 0)
    }

    @objc private func save() {
        do {
            let existingContents = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
            var updates = [
                "OVERLAY_THEME": selectedValue(from: themePopUp),
                "OVERLAY_TEXT_STYLE": selectedValue(from: textStylePopUp),
                "OVERLAY_TEXT_SIZE": selectedValue(from: textSizePopUp),
                "OVERLAY_DISPLAY_SECONDS": try displaySecondsValue(),
                "OVERLAY_BACKDROP_STYLE": selectedValue(from: backdropStylePopUp),
                "OVERLAY_PARTICLE_STYLE": selectedValue(from: particleStylePopUp)
            ]
            updates.merge(try healthReminderUpdates()) { _, new in new }
            updates.merge(try kanbanUpdates()) { _, new in new }
            updates.merge(aboutUpdates()) { _, new in new }

            let updatedContents = EnvConfigurationWriter.mergedContents(
                existingContents: existingContents,
                updates: updates
            )

            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try updatedContents.write(to: configURL, atomically: true, encoding: .utf8)

            window?.close()
            showSavedAlert()
        } catch {
            showErrorAlert(error)
        }
    }

    @objc private func cancel() {
        window?.close()
    }

    @objc private func selectSettingsPage() {
        tabView.selectTabViewItem(at: settingsSegmentedControl.selectedSegment)
    }

    @objc private func addCustomReminder() {
        addHealthReminderRow(
            AppConfiguration.HealthReminderConfiguration(
                id: nextCustomReminderID(),
                title: "自定义提醒",
                body: "写下你想提醒自己的事。",
                interval: 60 * 60,
                isEnabled: true
            )
        )
    }

    @objc private func deleteCustomReminder(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let index = healthReminderControls.firstIndex(where: { $0.id == id && !$0.isBuiltIn }) else {
            return
        }

        let controls = healthReminderControls.remove(at: index)
        healthReminderRowsStack.removeArrangedSubview(controls.rowView)
        controls.rowView.removeFromSuperview()
    }

    @objc private func testReminder() {
        do {
            let reminder = try healthReminderConfigurations().first { $0.isEnabled } ?? healthReminderConfigurations().first
            guard let reminder else {
                throw SettingsValidationError(message: "请先添加一条健康提醒。")
            }

            testReminderHandler(reminder.title, reminder.body)
        } catch {
            showErrorAlert(error)
        }
    }

    @objc private func chooseKanbanFile() {
        let panel = NSOpenPanel()
        panel.title = "选择 Obsidian Kanban Markdown 文件"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            .plainText
        ]

        if panel.runModal() == .OK, let url = panel.url {
            kanbanPathField.stringValue = url.path
            kanbanStatusLabel.stringValue = "已选择：\(url.lastPathComponent)"
        }
    }

    @objc private func testKanbanRead() {
        do {
            let updates = try kanbanUpdates()
            let tasks = try KanbanTaskReader().readInboxTasks(
                from: URL(fileURLWithPath: updates["KANBAN_PATH"] ?? ""),
                inboxSectionTitle: updates["KANBAN_INBOX_SECTION"] ?? ""
            )

            if tasks.isEmpty {
                kanbanStatusLabel.stringValue = "读取成功，但没有找到未完成任务。"
            } else {
                let preview = tasks.prefix(3).joined(separator: " · ")
                kanbanStatusLabel.stringValue = "读取成功：\(tasks.count) 条未完成任务。\(preview)"
            }
        } catch {
            kanbanStatusLabel.stringValue = "读取失败：\(error.localizedDescription)"
        }
    }

    @objc private func updateOverlayPreview() {
        overlayPreviewHostingView.rootView = ReminderOverlayPreviewView(
            title: "回到主线任务",
            messageBody: "整理今天最重要的一步。",
            configuration: previewOverlayConfiguration()
        )
    }

    private func selectedValue(from popUp: NSPopUpButton) -> String {
        popUp.selectedItem?.representedObject as? String ?? ""
    }

    private func displaySecondsValue() throws -> String {
        let rawValue = displaySecondsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(rawValue), value >= 2, value <= 12 else {
            throw SettingsValidationError(message: "显示时间必须是 2 到 12 秒之间的数字。")
        }

        return formattedSeconds(value)
    }

    private func previewOverlayConfiguration() -> AppConfiguration.Overlay {
        let current = AppConfiguration.load(from: configURL).overlay
        let displaySeconds = Double(displaySecondsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? current.displaySeconds

        return AppConfiguration.Overlay(
            displaySeconds: min(max(displaySeconds, 2), 12),
            fadeInSeconds: current.fadeInSeconds,
            fadeOutSeconds: current.fadeOutSeconds,
            backdropStyle: selectedValue(from: backdropStylePopUp).isEmpty
                ? current.backdropStyle
                : selectedValue(from: backdropStylePopUp),
            backdropOpacity: current.backdropOpacity,
            width: current.width,
            height: current.height,
            theme: selectedValue(from: themePopUp).isEmpty ? current.theme : selectedValue(from: themePopUp),
            textAlignment: current.textAlignment,
            textStyle: selectedValue(from: textStylePopUp).isEmpty ? current.textStyle : selectedValue(from: textStylePopUp),
            textSize: selectedValue(from: textSizePopUp).isEmpty ? current.textSize : selectedValue(from: textSizePopUp),
            position: current.position,
            verticalOffsetRatio: current.verticalOffsetRatio,
            particleStyle: selectedValue(from: particleStylePopUp).isEmpty
                ? current.particleStyle
                : selectedValue(from: particleStylePopUp),
            particleCount: current.particleCount,
            particleCanvasPadding: current.particleCanvasPadding,
            particleBirthRate: current.particleBirthRate,
            particleLifetimeSeconds: current.particleLifetimeSeconds,
            particleDurationSeconds: current.particleDurationSeconds,
            particleVelocity: current.particleVelocity,
            particleScale: current.particleScale
        )
    }

    private func healthReminderUpdates() throws -> [String: String] {
        let reminders = try healthReminderConfigurations()
        var updates: [String: String] = [
            "HEALTH_REMINDERS_ENABLED": healthRemindersEnabledButton.state == .on ? "true" : "false",
            "HEALTH_REMINDER_COUNTING_MODE": selectedValue(from: healthReminderCountingModePopUp),
            "HEALTH_REMINDER_IDS": reminders.map(\.id).joined(separator: ",")
        ]

        for reminder in reminders {
            let keyPrefix = "HEALTH_REMINDER_\(reminder.id.uppercased())"
            updates["\(keyPrefix)_ENABLED"] = reminder.isEnabled ? "true" : "false"
            updates["\(keyPrefix)_TITLE"] = reminder.title
            updates["\(keyPrefix)_BODY"] = reminder.body
            updates["\(keyPrefix)_INTERVAL_SECONDS"] = "\(Int(reminder.interval))"
        }

        return updates
    }

    private func kanbanUpdates() throws -> [String: String] {
        let path = kanbanPathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw SettingsValidationError(message: "Kanban 文件路径不能为空。")
        }

        return [
            "KANBAN_PATH": path,
            "KANBAN_INBOX_SECTION": kanbanSectionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    private func aboutUpdates() -> [String: String] {
        [
            "ABOUT_DEVELOPER_NAME": trimmedValue(from: aboutDeveloperNameField),
            "ABOUT_WEBSITE_URL": trimmedValue(from: aboutWebsiteURLField),
            "ABOUT_EMAIL": trimmedValue(from: aboutEmailField),
            "ABOUT_GITHUB_URL": trimmedValue(from: aboutGithubURLField),
            "ABOUT_COMMUNITY_URL": trimmedValue(from: aboutCommunityURLField),
            "ABOUT_FEEDBACK_URL": trimmedValue(from: aboutFeedbackURLField)
        ]
    }

    private func healthReminderConfigurations() throws -> [AppConfiguration.HealthReminderConfiguration] {
        try healthReminderControls.map { controls in
            let title = controls.titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = controls.bodyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let intervalText = controls.intervalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !title.isEmpty else {
                throw SettingsValidationError(message: "\(displayName(forHealthReminderID: controls.id)) 的标题不能为空。")
            }

            guard !body.isEmpty else {
                throw SettingsValidationError(message: "\(displayName(forHealthReminderID: controls.id)) 的正文不能为空。")
            }

            guard let intervalMinutes = Int(intervalText), intervalMinutes > 0 else {
                throw SettingsValidationError(message: "\(displayName(forHealthReminderID: controls.id)) 的间隔必须是大于 0 的整数分钟。")
            }

            return AppConfiguration.HealthReminderConfiguration(
                id: controls.id,
                title: title,
                body: body,
                interval: TimeInterval(intervalMinutes * 60),
                isEnabled: controls.enabledButton.state == .on
            )
        }
    }

    private func nextCustomReminderID() -> String {
        let existingIDs = Set(healthReminderControls.map(\.id))
        var index = 1

        while existingIDs.contains("custom_\(index)") {
            index += 1
        }

        return "custom_\(index)"
    }

    private func displayName(forHealthReminderID id: String) -> String {
        switch id {
        case "rest":
            return "休息"
        case "water":
            return "喝水"
        case "posture":
            return "坐姿"
        case "medicine":
            return "吃药"
        default:
            return "自定义"
        }
    }

    private func isBuiltInHealthReminderID(_ id: String) -> Bool {
        ["rest", "water", "posture", "medicine"].contains(id)
    }

    private func formattedSeconds(_ seconds: TimeInterval) -> String {
        seconds.rounded() == seconds ? "\(Int(seconds))" : "\(seconds)"
    }

    private func trimmedValue(from field: NSTextField) -> String {
        field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appVersionText() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }

    private func plusImage() -> NSImage {
        NSImage(systemSymbolName: "plus", accessibilityDescription: "添加健康提醒") ?? NSImage()
    }

    private func trashImage() -> NSImage {
        NSImage(systemSymbolName: "trash", accessibilityDescription: "删除健康提醒") ?? NSImage()
    }

    private func showSavedAlert() {
        let alert = NSAlert()
        alert.messageText = "设置已保存"
        alert.informativeText = "请退出并重新打开 HealthReminder，让新的设置生效。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showErrorAlert(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "保存设置失败"
        alert.runModal()
    }
}

private struct HealthReminderControls {
    let id: String
    let isBuiltIn: Bool
    let rowView: NSView
    let enabledButton: NSButton
    let titleField: NSTextField
    let bodyField: NSTextField
    let intervalField: NSTextField
}

private struct SettingsValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
