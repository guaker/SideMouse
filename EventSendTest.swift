import Cocoa
import Carbon.HIToolbox
import CoreGraphics

let source = CGEventSource(stateID: .hidSystemState)
let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_RightArrow), keyDown: true)!
let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_RightArrow), keyDown: false)!
down.flags = .maskControl
up.flags = .maskControl
down.post(tap: .cghidEventTap)
usleep(50000)
up.post(tap: .cghidEventTap)
