import Darwin
import Foundation

final class SingleInstanceLock {
    enum Failure: Error {
        case alreadyRunning
        case systemError(Int32)
    }

    private let descriptor: Int32

    init() throws {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("com.guaker.sidemouse.lock")
        let descriptor = Darwin.open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw Failure.systemError(errno) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw code == EWOULDBLOCK ? Failure.alreadyRunning : Failure.systemError(code)
        }
        self.descriptor = descriptor
    }

    deinit { Darwin.close(descriptor) }
}
