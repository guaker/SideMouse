import CoreGraphics
import Foundation
import OSLog

/// All event taps and state changes run on the main run loop.
final class MouseController {
    private let sender = ShortcutSender()
    private let logger = Logger(subsystem: "com.guaker.sidemouse", category: "MouseController")
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var didRequestListenAccess = false
    private var didRequestPostAccess = false
    private(set) var isListening = false
    private(set) var lastSideButton = "暂无"
    private(set) var lastAction = "暂无"
    private(set) var lastError = ""
    var onStatusChange: (() -> Void)?

    func start() -> Bool {
        guard eventTap == nil else { return isListening }
        guard CGPreflightListenEventAccess() else {
            lastError = "等待“输入监控”权限"
            if !didRequestListenAccess {
                didRequestListenAccess = true
                _ = CGRequestListenEventAccess()
            }
            return false
        }
        guard CGPreflightPostEventAccess() else {
            lastError = "等待“设备控制和数据访问 / 辅助功能”权限"
            if !didRequestPostAccess {
                didRequestPostAccess = true
                _ = CGRequestPostEventAccess()
            }
            return false
        }

        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<MouseController>.fromOpaque(context).takeUnretainedValue()
            return controller.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "无法创建鼠标事件监听，请检查输入监控权限"
            return false
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            lastError = "无法创建鼠标事件源"
            return false
        }
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isListening = true
        lastError = ""
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        eventTap = nil
        runLoopSource = nil
        isListening = false
        sender.cancel()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .otherMouseDown || type == .otherMouseUp,
              let direction = DesktopDirection(button: event.getIntegerValueField(.mouseEventButtonNumber)) else {
            return Unmanaged.passUnretained(event)
        }
        // Consume both halves of a side-button click; never tap keyboard or primary mouse events.
        if type == .otherMouseDown {
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isListening else { return }
                self.lastSideButton = "button \(button)"
                self.sender.send(direction.keyCode) { [weak self] sent in
                    guard let self else { return }
                    self.lastAction = sent
                        ? "已发送 \(direction.shortcutDescription)"
                        : "跳过：正在发送、有修饰键按下或无发送权限"
                    self.logger.debug("\(self.lastAction, privacy: .public)")
                    self.onStatusChange?()
                }
            }
        }
        return nil
    }

    deinit { stop() }
}
