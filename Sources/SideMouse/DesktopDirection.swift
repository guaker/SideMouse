import Carbon.HIToolbox
import CoreGraphics

enum DesktopDirection: CaseIterable {
    case right
    case left

    init?(button: Int64) {
        switch button {
        case 3: self = .right
        case 4: self = .left
        default: return nil
        }
    }

    var keyCode: CGKeyCode {
        switch self {
        case .left: return CGKeyCode(kVK_LeftArrow)
        case .right: return CGKeyCode(kVK_RightArrow)
        }
    }

    var shortcutDescription: String {
        self == .left ? "Control + ←" : "Control + →"
    }

    var mappingDescription: String {
        let button = self == .right ? 3 : 4
        return "侧键 \(button) → \(shortcutDescription)"
    }
}
