import Cocoa
import Carbon.HIToolbox

// Event fields and modifier sequence follow LinearMouse KeyKit (MIT).
final class ShortcutSender {
    private(set) var busy = false
    func send(_ key: CGKeyCode, completion: @escaping (Bool) -> Void) {
        guard !busy, CGPreflightPostEventAccess(),
              CGEventSource.flagsState(.combinedSessionState).intersection([.maskControl, .maskCommand, .maskAlternate, .maskShift]).isEmpty,
              let source = CGEventSource(stateID: .hidSystemState) else {
            completion(false)
            return
        }
        func event(_ code: CGKeyCode, _ down: Bool, _ flags: CGEventFlags, modifier: Bool = false) -> CGEvent? {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return nil }
            event.timestamp = CGEventTimestamp(DispatchTime.now().uptimeNanoseconds)
            event.setIntegerValueField(.keyboardEventKeyboardType, value: Int64(source.keyboardType))
            event.flags = flags
            if modifier { event.type = .flagsChanged }
            return event
        }
        let idle = CGEventSource.flagsState(.combinedSessionState).intersection(.maskAlphaShift).union(.maskNonCoalesced)
        let control = idle.union(.maskControl).union(CGEventFlags(rawValue: 1))
        guard let controlDown = event(CGKeyCode(kVK_Control), true, control, modifier: true),
              let arrowDown = event(key, true, control.union([.maskNumericPad, .maskSecondaryFn])),
              let arrowUp = event(key, false, control.union([.maskNumericPad, .maskSecondaryFn])),
              let controlUp = event(CGKeyCode(kVK_Control), false, idle, modifier: true) else {
            completion(false)
            return
        }
        busy = true
        controlDown.post(tap: .cgSessionEventTap)
        arrowDown.post(tap: .cgSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            arrowUp.timestamp = CGEventTimestamp(DispatchTime.now().uptimeNanoseconds)
            arrowUp.post(tap: .cgSessionEventTap)
            controlUp.timestamp = CGEventTimestamp(DispatchTime.now().uptimeNanoseconds)
            controlUp.post(tap: .cgSessionEventTap)
            self.busy = false
            completion(true)
        }
    }
}
