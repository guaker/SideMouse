import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Runs without XCTest or Accessibility access, using an in-memory event destination.
@main
enum ShortcutSenderTests {
    private struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("Only side buttons 3 and 4 are mapped", testMapping),
            ("Control and arrow event flags match the verified sequence", testEventSequence),
            ("Permissions and physical modifiers prevent posting", testGuards),
            ("Overlapping shortcuts are rejected and keys are released", testOverlappingSend),
            ("Cancellation releases keys once", testCancellation),
            ("Sending can restart after cancellation", testRestart)
        ]
        var failures = 0
        for (name, test) in tests {
            do {
                try test()
                print("PASS: \(name)")
            } catch {
                failures += 1
                fputs("FAIL: \(name): \(error)\n", stderr)
            }
        }
        print("\(tests.count - failures)/\(tests.count) regression checks passed")
        exit(failures == 0 ? 0 : 1)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(description: message) }
    }

    private static func waitUntil(_ condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        try expect(condition(), "Timed out waiting for key release")
    }

    private static func testMapping() throws {
        try expect(DesktopDirection(button: 3)?.keyCode == CGKeyCode(kVK_RightArrow), "Button 3 must map right")
        try expect(DesktopDirection(button: 4)?.keyCode == CGKeyCode(kVK_LeftArrow), "Button 4 must map left")
        for button: Int64 in [-1, 0, 1, 2, 5, 100] {
            try expect(DesktopDirection(button: button) == nil, "Unexpected mapping for button \(button)")
        }
    }

    private static func testEventSequence() throws {
        for direction in DesktopDirection.allCases {
            for capsLock in [CGEventFlags(), .maskAlphaShift] {
                guard let events = ShortcutSender.makeEvents(key: direction.keyCode, flags: capsLock) else {
                    throw Failure(description: "Cannot create keyboard events")
                }
                try expect(events.map(\.type) == [.flagsChanged, .keyDown, .keyUp, .flagsChanged], "Wrong event order")
                let codes = [Int64(kVK_Control), Int64(direction.keyCode), Int64(direction.keyCode), Int64(kVK_Control)]
                try expect(events.map { $0.getIntegerValueField(.keyboardEventKeycode) } == codes, "Wrong key codes")
                let idle = capsLock.union(.maskNonCoalesced)
                let control = idle.union(.maskControl).union(CGEventFlags(rawValue: 1))
                let arrow = control.union([.maskNumericPad, .maskSecondaryFn])
                try expect(events.map(\.flags) == [control, arrow, arrow, idle], "Wrong keyboard flags")
            }
        }
    }

    private static func testGuards() throws {
        for flags: CGEventFlags in [.maskControl, .maskCommand, .maskAlternate, .maskShift] {
            var count = 0
            var result: Bool?
            let sender = ShortcutSender(hasPostAccess: { true }, currentFlags: { flags }, post: { _ in count += 1 })
            sender.send(CGKeyCode(kVK_RightArrow)) { result = $0 }
            try expect(result == false && count == 0 && !sender.isBusy, "Held modifier must prevent posting")
        }
        var count = 0
        var result: Bool?
        let denied = ShortcutSender(hasPostAccess: { false }, currentFlags: { [] }, post: { _ in count += 1 })
        denied.send(CGKeyCode(kVK_RightArrow)) { result = $0 }
        try expect(result == false && count == 0, "Missing permission must prevent posting")
    }

    private static func testOverlappingSend() throws {
        var posted: [CGEventType] = []
        var result: Bool?
        let sender = ShortcutSender(hasPostAccess: { true }, currentFlags: { [] }, post: { posted.append($0.type) })
        sender.send(CGKeyCode(kVK_RightArrow)) { result = $0 }
        try expect(sender.isBusy && posted == [.flagsChanged, .keyDown], "Shortcut must stay busy while held")
        var overlappingResult: Bool?
        sender.send(CGKeyCode(kVK_LeftArrow)) { overlappingResult = $0 }
        try expect(overlappingResult == false, "An overlapping shortcut must be rejected")
        try waitUntil { result != nil }
        try expect(result == true && !sender.isBusy, "Shortcut did not finish")
        try expect(posted == [.flagsChanged, .keyDown, .keyUp, .flagsChanged], "Keys were not released in order")
    }

    private static func testCancellation() throws {
        var posted: [CGEvent] = []
        var results: [Bool] = []
        let sender = ShortcutSender(hasPostAccess: { true }, currentFlags: { [] }, post: { posted.append($0) })
        sender.send(CGKeyCode(kVK_RightArrow)) { results.append($0) }
        sender.cancel()
        sender.cancel()
        try expect(!sender.isBusy && results == [false], "Cancellation must complete once")
        try expect(posted.map(\.type) == [.flagsChanged, .keyDown, .keyUp, .flagsChanged], "Cancellation must release keys immediately")
        try expect(posted.last?.flags.contains(.maskControl) == false, "Control must be released")
        var settled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settled = true }
        try waitUntil { settled }
        try expect(posted.count == 4 && results == [false], "Cancelled task posted duplicate events")
    }

    private static func testRestart() throws {
        var posted: [CGEvent] = []
        var firstResult: Bool?
        var secondResult: Bool?
        let sender = ShortcutSender(hasPostAccess: { true }, currentFlags: { [] }, post: { posted.append($0) })
        sender.send(CGKeyCode(kVK_RightArrow)) { firstResult = $0 }
        sender.cancel()
        sender.send(CGKeyCode(kVK_LeftArrow)) { secondResult = $0 }
        try waitUntil { secondResult != nil }
        try expect(firstResult == false && secondResult == true && !sender.isBusy, "Sender failed to restart")
        try expect(posted.count == 8, "Each shortcut must have four events")
    }
}
