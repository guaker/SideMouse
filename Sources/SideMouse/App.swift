import Cocoa

@main
enum SideMouseApp {
    static func main() {
        do {
            let lock = try SingleInstanceLock()
            let application = NSApplication.shared
            let delegate = AppDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime((lock, delegate)) {
                application.run()
            }
        } catch SingleInstanceLock.Failure.alreadyRunning {
            guard let identifier = Bundle.main.bundleIdentifier else { return }
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
                .activate(options: [.activateAllWindows])
        } catch {
            fputs("SideMouse 启动失败：\(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = MouseController()
    private let statusWindow = StatusWindow()
    private var retryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.onStatusChange = { [weak self] in self?.refreshWindow() }
        tryStart()
        if !CommandLine.arguments.contains("--background") {
            statusWindow.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        refreshWindow()
        statusWindow.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        retryTimer?.invalidate()
        controller.stop()
    }

    private func tryStart() {
        retryTimer?.invalidate()
        retryTimer = nil
        if !controller.start() {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                self?.tryStart()
            }
        }
        refreshWindow()
    }

    private func refreshWindow() {
        statusWindow.refresh(controller: controller)
    }
}
