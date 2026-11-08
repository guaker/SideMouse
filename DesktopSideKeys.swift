import Cocoa
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import ApplicationServices
import Darwin

private enum DesktopDirection: Equatable {
    case left
    case right

    var keyCode: CGKeyCode {
        switch self {
        case .left: return CGKeyCode(kVK_LeftArrow)
        case .right: return CGKeyCode(kVK_RightArrow)
        }
    }
}

final class DesktopSideKeysController {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var didRequestListenAccess = false
    private var didRequestPostAccess = false
    private let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/DesktopSideKeys.log")
    private(set) var isListening = false
    private(set) var lastSideButton = "暂无"
    private(set) var lastAction = "暂无"
    private(set) var lastError = ""
    var onStatusChange: (() -> Void)?

    func start() -> Bool {
        if eventTap != nil { return true }

        guard CGPreflightListenEventAccess() else {
            isListening = false
            lastError = "等待“输入监控”权限"
            notifyStatus()
            if !didRequestListenAccess {
                didRequestListenAccess = true
                _ = CGRequestListenEventAccess()
                fputs("请在“系统设置 → 隐私与安全性 → 输入监控”中允许“鼠标侧切”。\n", stderr)
            }
            return false
        }

        guard CGPreflightPostEventAccess() else {
            isListening = false
            lastError = "等待“辅助功能”权限"
            notifyStatus()
            if !didRequestPostAccess {
                didRequestPostAccess = true
                _ = CGRequestPostEventAccess()
                fputs("请在“系统设置 → 隐私与安全性 → 辅助功能”中允许“鼠标侧切”。\n", stderr)
            }
            return false
        }

        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<DesktopSideKeysController>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .otherMouseDown || type == .otherMouseUp else {
                return Unmanaged.passUnretained(event)
            }
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            guard button == 3 || button == 4 else { return Unmanaged.passUnretained(event) }
            // Only consume a matching side-button pair. No keyboard/left/right events are tapped.
            if type == .otherMouseDown {
                let direction: DesktopDirection = button == 3 ? .right : .left
                controller.lastSideButton = "button \(button)"
                DispatchQueue.main.async { [weak controller] in
                    controller?.sendShortcut(direction)
                }
            }
            return nil
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            isListening = false
            lastError = "无法创建鼠标事件监听"
            notifyStatus()
            fputs("无法创建鼠标事件监听。请检查“输入监控”权限。\n", stderr)
            return false
        }

        eventTap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isListening = true
        lastError = ""
        notifyStatus()
        return true
    }

    private let sender = ShortcutSender()
    private func sendShortcut(_ direction: DesktopDirection) {
        sender.send(direction.keyCode) { [weak self] sent in
            guard let self else { return }
            let shortcut = direction == .left ? "Control + ←" : "Control + →"
            self.lastAction = sent ? "已发送 \(shortcut)" : "跳过：有修饰键按下或无发送权限"
            self.log(self.lastAction)
            self.notifyStatus()
        }
    }

    private func notifyStatus() {
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChange?()
        }
    }

    private func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = DesktopSideKeysController()
    private var retryTimer: Timer?
    private var observer: ShortcutObserver?
    private var window: NSWindow!
    private var permissionLabel: NSTextField!
    private var inputLabel: NSTextField!
    private var listeningLabel: NSTextField!
    private var mappingLabel: NSTextField!
    private var eventLabel: NSTextField!
    private var actionLabel: NSTextField!
    private var errorLabel: NSTextField!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--verify-mapping") {
            guard controller.start() else { NSApp.terminate(nil); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ShortcutVerification.verifyMouseMapping { NSApp.terminate(nil) }
            }
            return
        }
        if CommandLine.arguments.contains("--observe-shortcuts") {
            observer = ShortcutObserver()
            observer?.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 90) { NSApp.terminate(nil) }
            return
        }
        if CommandLine.arguments.contains("--verify-shortcuts") {
            ShortcutVerification.run(sender: ShortcutSender()) { NSApp.terminate(nil) }
            return
        }
        controller.onStatusChange = { [weak self] in self?.refreshWindow() }
        makeWindow()
        tryStart()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshWindow()
        return true
    }

    private func tryStart() {
        if controller.start() {
            retryTimer?.invalidate()
            retryTimer = nil
        } else {
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                self?.tryStart()
            }
        }
    }

    private func makeWindow() {
        let size = NSSize(width: 520, height: 380)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "SideMouse"
        window.isReleasedWhenClosed = false
        window.center()

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        window.contentView = content

        let title = NSTextField(labelWithString: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "SideMouse")
        title.font = .boldSystemFont(ofSize: 24)
        title.frame = NSRect(x: 28, y: 320, width: 450, height: 32)
        content.addSubview(title)

        permissionLabel = makeRow(in: content, y: 276, title: "快捷键发送权限")
        inputLabel = makeRow(in: content, y: 244, title: "输入监控权限")
        listeningLabel = makeRow(in: content, y: 212, title: "侧键监听")
        mappingLabel = makeRow(in: content, y: 170, title: "映射关系")
        mappingLabel.frame.size.height = 42
        mappingLabel.maximumNumberOfLines = 2
        eventLabel = makeRow(in: content, y: 128, title: "最近侧键")
        actionLabel = makeRow(in: content, y: 96, title: "最近动作")
        errorLabel = makeRow(in: content, y: 64, title: "状态")
        let quit = NSButton(title: "退出", target: self, action: #selector(quitApp))
        quit.bezelStyle = .rounded
        quit.frame = NSRect(x: 404, y: 16, width: 88, height: 30)
        content.addSubview(quit)
        let note = NSTextField(labelWithString: "关闭窗口后继续运行；点击退出可停止映射。")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 28, y: 22, width: 360, height: 18)
        content.addSubview(note)
        refreshWindow()
        if !CommandLine.arguments.contains("--background") {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    private func makeRow(in view: NSView, y: CGFloat, title: String) -> NSTextField {
        let key = NSTextField(labelWithString: title)
        key.textColor = .secondaryLabelColor
        key.frame = NSRect(x: 28, y: y, width: 110, height: 22)
        view.addSubview(key)

        let value = NSTextField(labelWithString: "")
        value.frame = NSRect(x: 165, y: y, width: 330, height: 22)
        view.addSubview(value)
        return value
    }

    private func refreshWindow() {
        guard window != nil else { return }
        let trusted = CGPreflightPostEventAccess()
        inputLabel.stringValue = CGPreflightListenEventAccess() ? "已允许" : "未允许"
        inputLabel.textColor = CGPreflightListenEventAccess() ? .systemGreen : .systemRed
        permissionLabel.stringValue = trusted ? "已允许" : "未允许"
        permissionLabel.textColor = trusted ? .systemGreen : .systemRed
        listeningLabel.stringValue = controller.isListening ? "运行中" : "等待授权"
        listeningLabel.textColor = controller.isListening ? .systemGreen : .systemOrange
        mappingLabel.stringValue = "侧键 1（3） → Control + →\n侧键 2（4） → Control + ←"
        eventLabel.stringValue = controller.lastSideButton
        actionLabel.stringValue = controller.lastAction
        errorLabel.stringValue = controller.lastError.isEmpty ? "等待侧键点击；不会修改系统快捷键" : controller.lastError
        errorLabel.textColor = controller.lastError.isEmpty ? .secondaryLabelColor : .systemOrange
    }
}

@main
struct DesktopSideKeysApp {
    private static var lockDescriptor: Int32 = -1
    static func main() {
        if !CommandLine.arguments.contains(where: { $0.hasPrefix("--verify-") || $0 == "--observe-shortcuts" }) {
            let lockURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/com.guaker.desktop-side-keys.lock")
            lockDescriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            guard lockDescriptor >= 0 else { return }
            guard flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 else {
                if let id = Bundle.main.bundleIdentifier {
                    NSRunningApplication.runningApplications(withBundleIdentifier: id)
                        .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })?
                        .activate(options: [.activateAllWindows])
                }
                return
            }
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}
