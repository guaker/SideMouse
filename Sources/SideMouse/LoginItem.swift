import Foundation
import OSLog
import ServiceManagement

final class LoginItem {
    private let service = SMAppService.mainApp
    private let defaults = UserDefaults.standard
    private let registrationKey = "DidSetUpLoginItem"
    private let logger = Logger(subsystem: "com.guaker.sidemouse", category: "LoginItem")
    private var registrationFailed = false

    func setUpIfNeeded() {
        guard !defaults.bool(forKey: registrationKey), isInstalled else { return }

        switch service.status {
        case .enabled, .requiresApproval:
            break
        default:
            do {
                try service.register()
            } catch {
                registrationFailed = true
                logger.error("Login item registration failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        // An item removed in System Settings should stay removed.
        defaults.set(true, forKey: registrationKey)
    }

    var statusText: String {
        switch service.status {
        case .enabled:
            return "已开启"
        case .requiresApproval:
            return "请在系统设置中允许"
        default:
            if registrationFailed { return "添加失败，可在系统设置中添加" }
            return isInstalled ? "未开启" : "移到“应用程序”后自动添加"
        }
    }

    private var isInstalled: Bool {
        let appPath = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
            .contains { appPath.hasPrefix($0.resolvingSymlinksInPath().path + "/") }
    }
}
