import Cocoa
import Darwin

// Read-only diagnostic: observe Spaces, never change them through private APIs.
enum ShortcutVerification {
    typealias Connection = @convention(c) () -> UInt32
    typealias Spaces = @convention(c) (UInt32) -> Unmanaged<CFArray>?
    static func snapshot() -> [[String: Any]] {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
              let first = dlsym(handle, "CGSMainConnectionID"),
              let second = dlsym(handle, "CGSCopyManagedDisplaySpaces") else { return [] }
        defer { dlclose(handle) }
        let connection = unsafeBitCast(first, to: Connection.self)
        let spaces = unsafeBitCast(second, to: Spaces.self)
        return spaces(connection())?.takeRetainedValue() as? [[String: Any]] ?? []
    }
    static func currentIDs() -> [Int] {
        snapshot().compactMap { ($0["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int }
    }
    static func run(sender: ShortcutSender, finish: @escaping () -> Void) {
        let log = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/DesktopSideKeys-verification.log")
        func write(_ text: String) {
            let line = "\(Date()) \(text)\n"
            if let handle = try? FileHandle(forWritingTo: log) {
                _ = try? handle.seekToEnd(); try? handle.write(contentsOf: Data(line.utf8)); try? handle.close()
            } else { try? Data(line.utf8).write(to: log) }
        }
        let before = currentIDs()
        write("postAccess=\(CGPreflightPostEventAccess()) listenAccess=\(CGPreflightListenEventAccess()) before=\(before)")
        guard CGPreflightPostEventAccess(), let display = snapshot().first,
              let spaces = display["Spaces"] as? [[String: Any]],
              let current = (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int,
              let index = spaces.firstIndex(where: { $0["ManagedSpaceID"] as? Int == current }), spaces.count > 1 else {
            write("Cannot run verification: permission or adjacent Space unavailable"); finish(); return
        }
        let right = index < spaces.count - 1
        let key: CGKeyCode = right ? 124 : 123
        sender.send(key) { sent in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                let after = currentIDs()
                write("key=\(key) sent=\(sent) after=\(after) changed=\(before != after)")
                guard before != after else { finish(); return }
                sender.send(right ? 123 : 124) { restored in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        write("reverseSent=\(restored) restored=\(currentIDs() == before) current=\(currentIDs())")
                        finish()
                    }
                }
            }
        }
    }
}

final class ShortcutObserver {
    private var taps: [CFMachPort] = []
    private var sources: [CFRunLoopSource] = []
    static let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/DesktopSideKeys-key-events.log")
    static func write(_ message: String) {
        let data = Data("\(Date()) \(message)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            _ = try? handle.seekToEnd(); try? handle.write(contentsOf: data); try? handle.close()
        } else { try? data.write(to: logURL) }
    }
    func start() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        for location in [CGEventTapLocation.cghidEventTap, .cgSessionEventTap, .cgAnnotatedSessionEventTap] {
            let callback: CGEventTapCallBack = { _, type, event, pointer in
                let code = event.getIntegerValueField(.keyboardEventKeycode)
                if [59, 62, 123, 124].contains(code) {
                    let site = UInt(bitPattern: pointer)
                    let message = "tap=\(site) type=\(type.rawValue) code=\(code) flags=\(String(event.flags.rawValue,radix:16)) pid=\(event.getIntegerValueField(.eventSourceUnixProcessID)) source=\(event.getIntegerValueField(.eventSourceStateID)) keyboard=\(event.getIntegerValueField(.keyboardEventKeyboardType)) time=\(event.timestamp)"
                    DispatchQueue.main.async { ShortcutObserver.write(message) }
                }
                return Unmanaged.passUnretained(event)
            }
            guard let tap = CGEvent.tapCreate(tap: location, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: callback, userInfo: UnsafeMutableRawPointer(bitPattern: Int(location.rawValue))),
                  let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                Self.write("observer creation failed location=\(location.rawValue)"); continue
            }
            taps.append(tap); sources.append(source)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        Self.write("observer ready postAccess=\(CGPreflightPostEventAccess()) taps=\(taps.count)")
    }
    deinit { taps.forEach { CFMachPortInvalidate($0) } }
}

extension ShortcutVerification {
    static func verifyMouseMapping(finish: @escaping () -> Void) {
        let before = currentIDs()
        guard let display = snapshot().first,
              let spaces = display["Spaces"] as? [[String: Any]],
              let current = (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int,
              let index = spaces.firstIndex(where: { $0["ManagedSpaceID"] as? Int == current }), spaces.count > 1 else {
            ShortcutObserver.write("mapping verification unavailable"); finish(); return
        }
        let right = index < spaces.count - 1
        func click(_ number: UInt32) {
            let location = CGEvent(source: nil)?.location ?? .zero
            let source = CGEventSource(stateID: .hidSystemState)
            for type in [CGEventType.otherMouseDown, .otherMouseUp] {
                let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: CGMouseButton(rawValue: number)!)!
                event.post(tap: .cghidEventTap)
            }
        }
        click(right ? 3 : 4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let after = currentIDs()
            ShortcutObserver.write("MAPPING button=\(right ? 3 : 4) before=\(before) after=\(after) changed=\(before != after)")
            guard before != after else { finish(); return }
            click(right ? 4 : 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ShortcutObserver.write("MAPPING reverseButton=\(right ? 4 : 3) current=\(currentIDs()) restored=\(before == currentIDs())")
                finish()
            }
        }
    }
}
