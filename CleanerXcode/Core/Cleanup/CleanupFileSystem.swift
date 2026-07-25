import Darwin
import Foundation

struct CleanupSecureTarget: Sendable {

    // MARK: - Public Properties

    let rootURL: URL
    let relativeComponents: [String]

    var url: URL {
        relativeComponents.reduce(rootURL) { partialURL, component in
            partialURL.appending(path: component, directoryHint: .isDirectory)
        }
    }

    // MARK: - Initializer

    init(_ rootURL: URL, relativeComponents: [String]) throws {
        let rootComponents = rootURL.pathComponents

        guard rootURL.isFileURL,
              rootComponents.first == "/",
              rootComponents.dropFirst().allSatisfy(Self.isSafePathComponent) else {
            throw CleanupSecureTargetError.invalidRoot(rootURL)
        }

        guard !relativeComponents.isEmpty, relativeComponents.allSatisfy(Self.isSafePathComponent) else {
            throw CleanupSecureTargetError.invalidRelativeComponents(relativeComponents)
        }

        self.rootURL = rootURL
        self.relativeComponents = relativeComponents
    }

    // MARK: - Private Methods

    private static func isSafePathComponent(_ component: String) -> Bool {
        !component.isEmpty
            && component != "."
            && component != ".."
            && !component.contains("/")
            && !component.utf8.contains(0)
    }
}

enum CleanupSecureTargetError: Error, LocalizedError, Sendable {
    case invalidRoot(URL)
    case invalidRelativeComponents([String])

    // MARK: - Public Properties

    var errorDescription: String? {
        switch self {
        case .invalidRoot(let url):
            "Cleanup root is not an absolute file URL: \(url.absoluteString)"
        case .invalidRelativeComponents:
            "Cleanup target contains an unsafe relative path component."
        }
    }
}

struct CleanupFileSystemError: Error, LocalizedError, Sendable {

    // MARK: - Public Properties

    let code: Int32
    let operation: String

    var errorDescription: String? {
        "\(operation): \(String(cString: strerror(code)))"
    }
}

private struct CleanupFileIdentity: Hashable {

    // MARK: - Private Properties

    private let device: dev_t
    private let inode: ino_t

    // MARK: - Initializer

    init(_ info: stat) {
        device = info.st_dev
        inode = info.st_ino
    }
}

protocol CleanupFileSystem: Sendable {
    func allocatedSize(of target: CleanupSecureTarget) throws -> Int64
    func remove(target: CleanupSecureTarget) throws
    func isFileNotFound(_ error: Error) -> Bool
}

protocol CleanupPOSIXOperations: Sendable {
    func close(_ descriptor: Int32)
    func directoryEntries(at descriptor: Int32) throws -> [String]
    func itemStatus(named name: String, in parentDescriptor: Int32) throws -> stat?
    func openRootDirectory() throws -> Int32
    func openDirectory(named name: String, in parentDescriptor: Int32) throws -> Int32
    func status(of descriptor: Int32) throws -> stat
    func unlink(_ name: String, from parentDescriptor: Int32, flags: Int32) throws
}

struct DarwinCleanupPOSIXOperations: CleanupPOSIXOperations, Sendable {

    // MARK: - Public Methods

    func close(_ descriptor: Int32) {
        _ = Darwin.close(descriptor)
    }

    func directoryEntries(at descriptor: Int32) throws -> [String] {
        let streamDescriptor = Darwin.dup(descriptor)
        guard streamDescriptor >= 0 else {
            throw CleanupFileSystemError(code: errno, operation: "dup")
        }

        errno = 0
        guard let directory = fdopendir(streamDescriptor) else {
            let errorCode = errno
            close(streamDescriptor)
            throw CleanupFileSystemError(code: errorCode, operation: "fdopendir")
        }

        defer { _ = closedir(directory) }

        var names = [String]()

        while true {
            errno = 0
            guard let entry = readdir(directory) else {
                let errorCode = errno

                if errorCode == 0 {
                    return names
                }

                throw CleanupFileSystemError(code: errorCode, operation: "readdir")
            }

            let name = entryName(entry)

            if name != ".", name != ".." {
                names.append(name)
            }
        }
    }

    func itemStatus(named name: String, in parentDescriptor: Int32) throws -> stat? {
        var info = stat()
        let result = name.withCString { fstatat(parentDescriptor, $0, &info, AT_SYMLINK_NOFOLLOW) }

        guard result == 0 else {
            if errno == ENOENT || errno == ENOTDIR {
                return nil
            }

            throw CleanupFileSystemError(code: errno, operation: "fstatat")
        }

        return info
    }

    func openRootDirectory() throws -> Int32 {
        let descriptor = "/".withCString { open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW) }
        guard descriptor >= 0 else {
            throw CleanupFileSystemError(code: errno, operation: "open")
        }

        return descriptor
    }

    func openDirectory(named name: String, in parentDescriptor: Int32) throws -> Int32 {
        let descriptor = name.withCString { openat(parentDescriptor, $0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW) }
        guard descriptor >= 0 else {
            throw CleanupFileSystemError(code: errno, operation: "openat")
        }

        return descriptor
    }

    func status(of descriptor: Int32) throws -> stat {
        var info = stat()
        guard fstat(descriptor, &info) == 0 else {
            throw CleanupFileSystemError(code: errno, operation: "fstat")
        }

        return info
    }

    func unlink(_ name: String, from parentDescriptor: Int32, flags: Int32) throws {
        let result = name.withCString { unlinkat(parentDescriptor, $0, flags) }
        guard result == 0 else {
            throw CleanupFileSystemError(code: errno, operation: "unlinkat")
        }
    }

    // MARK: - Private Methods

    private func entryName(_ entry: UnsafeMutablePointer<dirent>) -> String {
        withUnsafePointer(to: entry.pointee.d_name) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) {
                String(cString: $0)
            }
        }
    }
}

struct DescriptorAnchoredCleanupFileSystem: CleanupFileSystem, Sendable {

    // MARK: - Private Properties

    private let posix: any CleanupPOSIXOperations

    // MARK: - Initializer

    init(_ posix: any CleanupPOSIXOperations = DarwinCleanupPOSIXOperations()) {
        self.posix = posix
    }

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupSecureTarget) throws -> Int64 {
        do {
            var measuredIdentities = Set<CleanupFileIdentity>()

            return try withOpenedRoot(for: target) { rootDescriptor, rootDevice in
                try withParentDescriptor(for: target, rootDescriptor: rootDescriptor, rootDevice: rootDevice) { parentDescriptor, itemName in
                    guard let itemInfo = try posix.itemStatus(named: itemName, in: parentDescriptor) else {
                        return 0
                    }

                    try validate(itemInfo, belongsTo: rootDevice, operation: "fstatat")

                    if isSymbolicLink(itemInfo) {
                        return 0
                    }

                    if isDirectory(itemInfo) {
                        return try withOpenedDirectory(named: itemName, in: parentDescriptor, rootDevice: rootDevice) { descriptor in
                            try allocatedSize(ofDirectory: descriptor, rootDevice: rootDevice, measuredIdentities: &measuredIdentities)
                        }
                    }

                    return allocatedSize(of: itemInfo, measuredIdentities: &measuredIdentities)
                }
            }
        } catch {
            guard isFileNotFound(error) else {
                throw error
            }

            return 0
        }
    }

    func remove(target: CleanupSecureTarget) throws {
        try withOpenedRoot(for: target) { rootDescriptor, rootDevice in
            try withParentDescriptor(for: target, rootDescriptor: rootDescriptor, rootDevice: rootDevice) { parentDescriptor, itemName in
                guard let itemInfo = try posix.itemStatus(named: itemName, in: parentDescriptor) else {
                    throw CleanupFileSystemError(code: ENOENT, operation: "fstatat")
                }

                try validate(itemInfo, belongsTo: rootDevice, operation: "fstatat")

                if isDirectory(itemInfo), !isSymbolicLink(itemInfo) {
                    try withOpenedDirectory(named: itemName, in: parentDescriptor, rootDevice: rootDevice) { descriptor in
                        try removeContents(ofDirectory: descriptor, rootDevice: rootDevice)
                    }
                    try unlink(itemName, from: parentDescriptor, expectedInfo: itemInfo, flags: AT_REMOVEDIR, rootDevice: rootDevice)
                } else {
                    try unlink(itemName, from: parentDescriptor, expectedInfo: itemInfo, flags: 0, rootDevice: rootDevice)
                }
            }
        }
    }

    func isFileNotFound(_ error: Error) -> Bool {
        guard let error = error as? CleanupFileSystemError else {
            return false
        }

        return error.code == ENOENT || error.code == ENOTDIR
    }

    // MARK: - Private Methods

    private func allocatedSize(
        ofDirectory descriptor: Int32,
        rootDevice: dev_t,
        measuredIdentities: inout Set<CleanupFileIdentity>
    ) throws -> Int64 {
        let info = try posix.status(of: descriptor)
        try validate(info, belongsTo: rootDevice, operation: "fstat")
        guard measuredIdentities.insert(.init(info)).inserted else {
            return 0
        }

        var total = physicalBlockSize(of: info)
        var processedNames = Set<String>()

        for attempt in 0..<2 {
            var shouldRetry = false
            let names = try posix.directoryEntries(at: descriptor)

            for name in names where !processedNames.contains(name) {
                guard let itemInfo = try posix.itemStatus(named: name, in: descriptor) else {
                    shouldRetry = true
                    continue
                }

                try validate(itemInfo, belongsTo: rootDevice, operation: "fstatat")

                if isSymbolicLink(itemInfo) {
                    processedNames.insert(name)
                    continue
                }

                if isDirectory(itemInfo) {
                    do {
                        total += try withOpenedDirectory(named: name, in: descriptor, rootDevice: rootDevice) { childDescriptor in
                            try allocatedSize(
                                ofDirectory: childDescriptor,
                                rootDevice: rootDevice,
                                measuredIdentities: &measuredIdentities
                            )
                        }
                        processedNames.insert(name)
                    } catch {
                        guard isFileNotFound(error) else {
                            throw error
                        }

                        shouldRetry = true
                    }
                } else {
                    total += allocatedSize(of: itemInfo, measuredIdentities: &measuredIdentities)
                    processedNames.insert(name)
                }
            }

            if !shouldRetry || attempt == 1 {
                return total
            }
        }

        return total
    }

    private func allocatedSize(of info: stat, measuredIdentities: inout Set<CleanupFileIdentity>) -> Int64 {
        guard measuredIdentities.insert(.init(info)).inserted else {
            return 0
        }

        return physicalBlockSize(of: info)
    }

    private func physicalBlockSize(of info: stat) -> Int64 {
        Int64(info.st_blocks) * 512
    }

    private func isDirectory(_ info: stat) -> Bool {
        info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR)
    }

    private func isSameFile(_ first: stat, _ second: stat) -> Bool {
        first.st_dev == second.st_dev && first.st_ino == second.st_ino
    }

    private func isSymbolicLink(_ info: stat) -> Bool {
        info.st_mode & mode_t(S_IFMT) == mode_t(S_IFLNK)
    }

    private func removeContents(ofDirectory descriptor: Int32, rootDevice: dev_t) throws {
        let info = try posix.status(of: descriptor)
        try validate(info, belongsTo: rootDevice, operation: "fstat")
        var processedNames = Set<String>()

        for attempt in 0..<2 {
            var shouldRetry = false
            let names = try posix.directoryEntries(at: descriptor)

            for name in names where !processedNames.contains(name) {
                guard let itemInfo = try posix.itemStatus(named: name, in: descriptor) else {
                    shouldRetry = true
                    continue
                }

                try validate(itemInfo, belongsTo: rootDevice, operation: "fstatat")

                if isDirectory(itemInfo), !isSymbolicLink(itemInfo) {
                    do {
                        try withOpenedDirectory(named: name, in: descriptor, rootDevice: rootDevice) { childDescriptor in
                            try removeContents(ofDirectory: childDescriptor, rootDevice: rootDevice)
                        }
                        try unlink(name, from: descriptor, expectedInfo: itemInfo, flags: AT_REMOVEDIR, rootDevice: rootDevice)
                        processedNames.insert(name)
                    } catch {
                        guard isFileNotFound(error) else {
                            throw error
                        }

                        shouldRetry = true
                    }
                } else {
                    do {
                        try unlink(name, from: descriptor, expectedInfo: itemInfo, flags: 0, rootDevice: rootDevice)
                        processedNames.insert(name)
                    } catch {
                        guard isFileNotFound(error) else {
                            throw error
                        }

                        shouldRetry = true
                    }
                }
            }

            if !shouldRetry || attempt == 1 {
                return
            }
        }
    }

    private func unlink(
        _ name: String,
        from parentDescriptor: Int32,
        expectedInfo: stat,
        flags: Int32,
        rootDevice: dev_t
    ) throws {
        guard let currentInfo = try posix.itemStatus(named: name, in: parentDescriptor) else {
            throw CleanupFileSystemError(code: ENOENT, operation: "fstatat")
        }

        try validate(currentInfo, belongsTo: rootDevice, operation: "fstatat")

        guard isSameFile(expectedInfo, currentInfo) else {
            throw CleanupFileSystemError(code: EAGAIN, operation: "unlinkat")
        }

        try posix.unlink(name, from: parentDescriptor, flags: flags)
    }

    private func validate(_ info: stat, belongsTo rootDevice: dev_t, operation: String) throws {
        guard info.st_dev == rootDevice else {
            throw CleanupFileSystemError(code: EXDEV, operation: operation)
        }
    }

    private func withOpenedDirectory<T>(
        named name: String,
        in parentDescriptor: Int32,
        rootDevice: dev_t,
        operation: (Int32) throws -> T
    ) throws -> T {
        let descriptor = try openVerifiedDirectory(named: name, in: parentDescriptor, rootDevice: rootDevice)

        defer { posix.close(descriptor) }

        return try operation(descriptor)
    }

    private func openVerifiedDirectory(named name: String, in parentDescriptor: Int32, rootDevice: dev_t) throws -> Int32 {
        guard let expectedInfo = try posix.itemStatus(named: name, in: parentDescriptor) else {
            throw CleanupFileSystemError(code: ENOENT, operation: "fstatat")
        }

        try validate(expectedInfo, belongsTo: rootDevice, operation: "fstatat")

        guard !isSymbolicLink(expectedInfo) else {
            throw CleanupFileSystemError(code: ELOOP, operation: "fstatat")
        }

        let descriptor = try posix.openDirectory(named: name, in: parentDescriptor)

        do {
            let actualInfo = try posix.status(of: descriptor)
            try validate(actualInfo, belongsTo: rootDevice, operation: "fstat")

            guard isSameFile(expectedInfo, actualInfo) else {
                throw CleanupFileSystemError(code: EAGAIN, operation: "openat")
            }
        } catch {
            posix.close(descriptor)
            throw error
        }

        return descriptor
    }

    private func withOpenedRoot<T>(
        for target: CleanupSecureTarget,
        operation: (Int32, dev_t) throws -> T
    ) throws -> T {
        let descriptor = try openDirectoryChain(at: target.rootURL)

        defer { posix.close(descriptor) }

        let info = try posix.status(of: descriptor)

        return try operation(descriptor, info.st_dev)
    }

    private func withParentDescriptor<T>(
        for target: CleanupSecureTarget,
        rootDescriptor: Int32,
        rootDevice: dev_t,
        operation: (Int32, String) throws -> T
    ) throws -> T {
        guard let itemName = target.relativeComponents.last else {
            throw CleanupFileSystemError(code: EINVAL, operation: "openat")
        }

        var descriptors = [Int32]()
        var parentDescriptor = rootDescriptor

        defer { descriptors.reversed().forEach(posix.close) }

        for component in target.relativeComponents.dropLast() {
            let descriptor = try openVerifiedDirectory(named: component, in: parentDescriptor, rootDevice: rootDevice)
            descriptors.append(descriptor)
            parentDescriptor = descriptor
        }

        return try operation(parentDescriptor, itemName)
    }

    private func openDirectoryChain(at url: URL) throws -> Int32 {
        guard url.isFileURL, url.path.hasPrefix("/") else {
            throw CleanupFileSystemError(code: EINVAL, operation: "open")
        }

        let rootDescriptor = try posix.openRootDirectory()
        var descriptors = [rootDescriptor]
        var parentDescriptor = rootDescriptor

        do {
            for component in url.pathComponents.dropFirst() {
                guard let expectedInfo = try posix.itemStatus(named: component, in: parentDescriptor) else {
                    throw CleanupFileSystemError(code: ENOENT, operation: "fstatat")
                }

                guard !isSymbolicLink(expectedInfo) else {
                    throw CleanupFileSystemError(code: ELOOP, operation: "fstatat")
                }

                let descriptor = try posix.openDirectory(named: component, in: parentDescriptor)

                do {
                    let actualInfo = try posix.status(of: descriptor)

                    guard isSameFile(expectedInfo, actualInfo) else {
                        throw CleanupFileSystemError(code: EAGAIN, operation: "openat")
                    }
                } catch {
                    posix.close(descriptor)
                    throw error
                }

                descriptors.append(descriptor)
                parentDescriptor = descriptor
            }

            descriptors.removeLast()
            descriptors.reversed().forEach(posix.close)
            return parentDescriptor
        } catch {
            descriptors.reversed().forEach(posix.close)
            throw error
        }
    }
}
