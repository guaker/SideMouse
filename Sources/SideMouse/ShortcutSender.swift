import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Sends and releases shortcuts on the main queue. Event fields follow LinearMouse KeyKit (MIT).
final class ShortcutSender {
    private let hasPostAccess: () -> Bool
    private let currentFlags: () -> CGEventFlags
    private let post: (CGEvent) -> Void
    private var pendingEvents: [CGEvent] = []
    private var completion: ((Bool) -> Void)?
    private var releaseTask: DispatchWorkItem?
    var isBusy: Bool { !pendingEvents.isEmpty }

    init(
        hasPostAccess: @escaping () -> Bool = { CGPreflightPostEventAccess() },
        currentFlags: @escaping () -> CGEventFlags = { CGEventSource.flagsState(.combinedSessionState) },
        post: @escaping (CGEvent) -> Void = { $0.post(tap: .cgSessionEventTap) }
    ) {
        self.hasPostAccess = hasPostAccess
        self.currentFlags = currentFlags
        self.post = post
    }

    func send(_ key: CGKeyCode, completion: @escaping (Bool) -> Void) {
        let flags = currentFlags()
        guard !isBusy, hasPostAccess(),
              flags.intersection([.maskControl, .maskCommand, .maskAlternate, .maskShift]).isEmpty,
              let events = Self.makeEvents(key: key, flags: flags) else {
            completion(false)
            return
        }
        pendingEvents = Array(events.suffix(2))
        self.completion = completion
        events.prefix(2).forEach(postEvent)
        let task = DispatchWorkItem { [weak self] in self?.release(sent: true) }
        releaseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: task)
    }

    /// Release any synthetic keys immediately when the application stops.
    func cancel() {
        releaseTask?.cancel()
        release(sent: false)
    }

    private func release(sent: Bool) {
        let events = pendingEvents
        let callback = completion
        pendingEvents = []
        completion = nil
        releaseTask = nil
        events.forEach(postEvent)
        callback?(sent)
    }

    private func postEvent(_ event: CGEvent) {
        event.timestamp = CGEventTimestamp(DispatchTime.now().uptimeNanoseconds)
        post(event)
    }

    static func makeEvents(key: CGKeyCode, flags: CGEventFlags) -> [CGEvent]? {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return nil }
        func event(_ code: CGKeyCode, down: Bool, flags: CGEventFlags, modifier: Bool = false) -> CGEvent? {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return nil }
            event.setIntegerValueField(.keyboardEventKeyboardType, value: Int64(source.keyboardType))
            event.flags = flags
            if modifier { event.type = .flagsChanged }
            return event
        }
        let idle = flags.intersection(.maskAlphaShift).union(.maskNonCoalesced)
        // Bit 0 marks the left Control key; arrow events also require NumericPad and SecondaryFn.
        let control = idle.union(.maskControl).union(CGEventFlags(rawValue: 1))
        let arrow = control.union([.maskNumericPad, .maskSecondaryFn])
        guard let controlDown = event(CGKeyCode(kVK_Control), down: true, flags: control, modifier: true),
              let arrowDown = event(key, down: true, flags: arrow),
              let arrowUp = event(key, down: false, flags: arrow),
              let controlUp = event(CGKeyCode(kVK_Control), down: false, flags: idle, modifier: true) else {
            return nil
        }
        return [controlDown, arrowDown, arrowUp, controlUp]
    }

    deinit { cancel() }
}
