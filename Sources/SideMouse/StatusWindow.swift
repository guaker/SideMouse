import Cocoa

final class StatusWindow: NSObject {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    private let permissionLabel = NSTextField(labelWithString: "")
    private let inputLabel = NSTextField(labelWithString: "")
    private let listeningLabel = NSTextField(labelWithString: "")
    private let mappingLabel = NSTextField(labelWithString: "")
    private let eventLabel = NSTextField(labelWithString: "")
    private let actionLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")
    var onRetry: (() -> Void)?

    override init() {
        super.init()
        makeWindow()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() {
        let size = NSSize(width: 520, height: 400)
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "SideMouse"
        window.isReleasedWhenClosed = false
        window.center()

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        window.contentView = content

        let title = NSTextField(labelWithString: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "SideMouse")
        title.font = .boldSystemFont(ofSize: 24)
        title.frame = NSRect(x: 28, y: 320, width: 450, height: 32)
        content.addSubview(title)

        makeRow(permissionLabel, in: content, y: 276, title: "快捷键发送权限")
        makeRow(inputLabel, in: content, y: 244, title: "输入监控权限")
        makeRow(listeningLabel, in: content, y: 212, title: "侧键监听")
        makeRow(mappingLabel, in: content, y: 170, title: "映射关系")
        mappingLabel.frame.size.height = 42
        mappingLabel.maximumNumberOfLines = 2
        makeRow(eventLabel, in: content, y: 128, title: "最近侧键")
        makeRow(actionLabel, in: content, y: 96, title: "最近动作")
        makeRow(errorLabel, in: content, y: 64, title: "状态")
        errorLabel.maximumNumberOfLines = 2
        errorLabel.frame.size.height = 34
        errorLabel.lineBreakMode = .byWordWrapping
        let inputSettings = NSButton(title: "输入监控设置", target: self, action: #selector(openInputMonitoringSettings))
        inputSettings.bezelStyle = .rounded
        inputSettings.frame = NSRect(x: 28, y: 16, width: 110, height: 30)
        content.addSubview(inputSettings)
        let accessibilitySettings = NSButton(title: "辅助功能设置", target: self, action: #selector(openAccessibilitySettings))
        accessibilitySettings.bezelStyle = .rounded
        accessibilitySettings.frame = NSRect(x: 146, y: 16, width: 110, height: 30)
        content.addSubview(accessibilitySettings)
        let retry = NSButton(title: "重新检测", target: self, action: #selector(retryPermissions))
        retry.bezelStyle = .rounded
        retry.frame = NSRect(x: 264, y: 16, width: 100, height: 30)
        content.addSubview(retry)
        let quit = NSButton(title: "退出", target: self, action: #selector(quitApp))
        quit.bezelStyle = .rounded
        quit.frame = NSRect(x: 404, y: 16, width: 88, height: 30)
        content.addSubview(quit)
        let note = NSTextField(labelWithString: "授权后返回此窗口会自动检测；关闭窗口后映射继续运行。")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 28, y: 48, width: 464, height: 16)
        content.addSubview(note)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func openInputMonitoringSettings() {
        openSettingsPane("Privacy_ListenEvent")
    }

    @objc private func openAccessibilitySettings() {
        openSettingsPane("Privacy_Accessibility")
    }

    private func openSettingsPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func retryPermissions() { onRetry?() }

    private func makeRow(_ value: NSTextField, in view: NSView, y: CGFloat, title: String) {
        let key = NSTextField(labelWithString: title)
        key.textColor = .secondaryLabelColor
        key.frame = NSRect(x: 28, y: y, width: 110, height: 22)
        view.addSubview(key)

        value.frame = NSRect(x: 165, y: y, width: 330, height: 22)
        view.addSubview(value)
    }

    func refresh(controller: MouseController) {
        let trusted = CGPreflightPostEventAccess()
        let canListen = CGPreflightListenEventAccess()
        inputLabel.stringValue = canListen ? "已允许" : "未允许"
        inputLabel.textColor = canListen ? .systemGreen : .systemRed
        permissionLabel.stringValue = trusted ? "已允许" : "未允许"
        permissionLabel.textColor = trusted ? .systemGreen : .systemRed
        listeningLabel.stringValue = controller.isListening ? "运行中" : "未运行"
        listeningLabel.textColor = controller.isListening ? .systemGreen : .systemOrange
        mappingLabel.stringValue = DesktopDirection.allCases.map(\.mappingDescription).joined(separator: "\n")
        eventLabel.stringValue = controller.lastSideButton
        actionLabel.stringValue = controller.lastAction
        errorLabel.stringValue = controller.lastError.isEmpty ? "等待侧键点击；不会修改系统快捷键" : controller.lastError
        errorLabel.textColor = controller.lastError.isEmpty ? .secondaryLabelColor : .systemOrange
    }
}
