import Darwin
import Foundation
import Testing

@testable import CleanerXcode

struct DescriptorAnchoredCleanupFileSystemTests {

    // MARK: - Public Methods

    @Test
    func rejectsAMountBeforeMeasuringItsContents() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 1, inode: 2))],
            .init(2, "DerivedData"): [
                .some(directoryInfo(device: 2, inode: 3)),
                .some(directoryInfo(device: 2, inode: 3))
            ]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 1, inode: 2),
            3: directoryInfo(device: 2, inode: 3)
        ]
        operations.openDescriptors = [2, 3]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])

        #expect(throws: CleanupFileSystemError.self) {
            try DescriptorAnchoredCleanupFileSystem(operations).allocatedSize(of: target)
        }
        #expect(operations.directoryEntryCallCount == 0)
    }

    @Test
    func acceptsACleanupRootOnADifferentDeviceThanTheAbsoluteRoot() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 2, inode: 2))],
            .init(2, "DerivedData"): [.some(fileInfo(device: 2, inode: 3, blocks: 8))]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 2, inode: 2)
        ]
        operations.openDescriptors = [2]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])

        let size = try DescriptorAnchoredCleanupFileSystem(operations).allocatedSize(of: target)

        #expect(size == 4_096)
        #expect(operations.directoryEntryCallCount == 0)
    }

    @Test
    func rejectsAMountInARelativeAncestorBeforeItCanReachTheTarget() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 2, inode: 2))],
            .init(2, "Developer"): [.some(directoryInfo(device: 3, inode: 3))]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 2, inode: 2),
            3: directoryInfo(device: 3, inode: 3)
        ]
        operations.openDescriptors = [2]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["Developer", "DerivedData"])

        #expect(throws: CleanupFileSystemError.self) {
            try DescriptorAnchoredCleanupFileSystem(operations).allocatedSize(of: target)
        }
        #expect(operations.directoryEntryCallCount == 0)
    }

    @Test
    func rejectsAnIdentityChangeBetweenFstatatAndOpenat() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 1, inode: 2))],
            .init(2, "DerivedData"): [
                .some(directoryInfo(device: 1, inode: 3, blocks: 4)),
                .some(directoryInfo(device: 1, inode: 3, blocks: 4))
            ]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 1, inode: 2),
            3: directoryInfo(device: 1, inode: 4)
        ]
        operations.openDescriptors = [2, 3]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])

        #expect(throws: CleanupFileSystemError.self) {
            try DescriptorAnchoredCleanupFileSystem(operations).allocatedSize(of: target)
        }
        #expect(operations.directoryEntryCallCount == 0)
    }

    @Test
    func rejectsAnIdentityChangeImmediatelyBeforeUnlinkat() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 1, inode: 2))],
            .init(2, "DerivedData"): [
                .some(directoryInfo(device: 1, inode: 3)),
                .some(directoryInfo(device: 1, inode: 3)),
                .some(directoryInfo(device: 1, inode: 4))
            ]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 1, inode: 2),
            3: directoryInfo(device: 1, inode: 3, blocks: 4)
        ]
        operations.openDescriptors = [2, 3]
        operations.directoryEntryResults = [[]]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])

        #expect(throws: CleanupFileSystemError.self) {
            try DescriptorAnchoredCleanupFileSystem(operations).remove(target: target)
        }
        #expect(operations.unlinkCallCount == 0)
    }

    @Test
    func propagatesAReaddirFailure() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 1, inode: 2))],
            .init(2, "DerivedData"): [
                .some(directoryInfo(device: 1, inode: 3, blocks: 4)),
                .some(directoryInfo(device: 1, inode: 3, blocks: 4))
            ]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 1, inode: 2),
            3: directoryInfo(device: 1, inode: 3, blocks: 4)
        ]
        operations.openDescriptors = [2, 3]
        operations.directoryEntryErrors = [CleanupFileSystemError(code: EIO, operation: "readdir")]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])

        #expect(throws: CleanupFileSystemError.self) {
            try DescriptorAnchoredCleanupFileSystem(operations).allocatedSize(of: target)
        }
    }

    @Test
    func retriesOnceWhenAChildDisappearsWithoutDiscardingTheTarget() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 1, inode: 2))],
            .init(2, "DerivedData"): [
                .some(directoryInfo(device: 1, inode: 3)),
                .some(directoryInfo(device: 1, inode: 3))
            ],
            .init(3, "vanishing-file"): [.none]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 1, inode: 2),
            3: directoryInfo(device: 1, inode: 3)
        ]
        operations.openDescriptors = [2, 3]
        operations.directoryEntryResults = [["vanishing-file"], []]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])

        _ = try DescriptorAnchoredCleanupFileSystem(operations).allocatedSize(of: target)

        #expect(operations.directoryEntryCallCount == 2)
    }

    @Test
    func removesTheTargetWhenAChildDisappearsWithoutReportingTheTargetAsMissing() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 1, inode: 2))],
            .init(2, "DerivedData"): [
                .some(directoryInfo(device: 1, inode: 3)),
                .some(directoryInfo(device: 1, inode: 3)),
                .some(directoryInfo(device: 1, inode: 3))
            ],
            .init(3, "vanishing-file"): [.none]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 1, inode: 2),
            3: directoryInfo(device: 1, inode: 3)
        ]
        operations.openDescriptors = [2, 3]
        operations.directoryEntryResults = [["vanishing-file"], []]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])

        try DescriptorAnchoredCleanupFileSystem(operations).remove(target: target)

        #expect(operations.directoryEntryCallCount == 2)
        #expect(operations.unlinkCallCount == 1)
    }

    @Test
    func rejectsUnsafeSecureTargetComponentsAtThePOSIXBoundary() throws {
        #expect(throws: CleanupSecureTargetError.self) {
            try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: [""])
        }

        #expect(throws: CleanupSecureTargetError.self) {
            try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["."])
        }

        #expect(throws: CleanupSecureTargetError.self) {
            try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["../DerivedData"])
        }

        #expect(throws: CleanupSecureTargetError.self) {
            try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["Derived/Data"])
        }

        #expect(throws: CleanupSecureTargetError.self) {
            try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["\0"])
        }
    }

    @Test
    func countsPhysicalBlocksOnceForHardLinkedFiles() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [.some(directoryInfo(device: 1, inode: 2))],
            .init(2, "DerivedData"): [
                .some(directoryInfo(device: 1, inode: 3, blocks: 4)),
                .some(directoryInfo(device: 1, inode: 3, blocks: 4))
            ],
            .init(3, "first"): [.some(fileInfo(device: 1, inode: 4, blocks: 8))],
            .init(3, "second"): [.some(fileInfo(device: 1, inode: 4, blocks: 8))]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 1, inode: 2),
            3: directoryInfo(device: 1, inode: 3, blocks: 4)
        ]
        operations.openDescriptors = [2, 3]
        operations.directoryEntryResults = [["first", "second"]]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])

        let size = try DescriptorAnchoredCleanupFileSystem(operations).allocatedSize(of: target)

        #expect(size == 6_144)
    }

    @Test
    func scopesPhysicalBlockDeduplicationToOneMeasurement() throws {
        let operations = ScriptedPOSIXOperations()
        operations.itemInfos = [
            .init(1, "trusted"): [
                .some(directoryInfo(device: 1, inode: 2)),
                .some(directoryInfo(device: 1, inode: 2))
            ],
            .init(2, "DerivedData"): [
                .some(fileInfo(device: 1, inode: 3, blocks: 8)),
                .some(fileInfo(device: 1, inode: 3, blocks: 8))
            ]
        ]
        operations.descriptorInfos = [
            1: directoryInfo(device: 1, inode: 1),
            2: directoryInfo(device: 1, inode: 2)
        ]
        operations.openDescriptors = [2, 2]
        let target = try CleanupSecureTarget(URL(filePath: "/trusted", directoryHint: .isDirectory), relativeComponents: ["DerivedData"])
        let fileSystem = DescriptorAnchoredCleanupFileSystem(operations)

        let firstMeasurement = try fileSystem.allocatedSize(of: target)
        let secondMeasurement = try fileSystem.allocatedSize(of: target)

        #expect(firstMeasurement == 4_096)
        #expect(secondMeasurement == 4_096)
    }
}

private final class ScriptedPOSIXOperations: CleanupPOSIXOperations, @unchecked Sendable {

    // MARK: - Public Properties

    var descriptorInfos = [Int32: Darwin.stat]()
    var directoryEntryErrors = [CleanupFileSystemError]()
    var directoryEntryResults = [[String]]()
    var itemInfos = [POSIXItemKey: [Darwin.stat?]]()
    var openDescriptors = [Int32]()
    private(set) var directoryEntryCallCount = 0
    private(set) var unlinkCallCount = 0

    // MARK: - Private Properties

    private var itemInfoIndexes = [POSIXItemKey: Int]()

    // MARK: - Public Methods

    func close(_ descriptor: Int32) {}

    func directoryEntries(at descriptor: Int32) throws -> [String] {
        directoryEntryCallCount += 1

        if !directoryEntryErrors.isEmpty {
            throw directoryEntryErrors.removeFirst()
        }

        return directoryEntryResults.isEmpty ? [] : directoryEntryResults.removeFirst()
    }

    func itemStatus(named name: String, in parentDescriptor: Int32) throws -> Darwin.stat? {
        let key = POSIXItemKey(parentDescriptor, name)
        let index = itemInfoIndexes[key, default: 0]
        itemInfoIndexes[key] = index + 1
        return itemInfos[key]?[safe: index] ?? nil
    }

    func openRootDirectory() throws -> Int32 {
        1
    }

    func openDirectory(named name: String, in parentDescriptor: Int32) throws -> Int32 {
        guard !openDescriptors.isEmpty else {
            throw CleanupFileSystemError(code: ENOENT, operation: "openat")
        }

        return openDescriptors.removeFirst()
    }

    func status(of descriptor: Int32) throws -> Darwin.stat {
        guard let info = descriptorInfos[descriptor] else {
            throw CleanupFileSystemError(code: EBADF, operation: "fstat")
        }

        return info
    }

    func unlink(_ name: String, from parentDescriptor: Int32, flags: Int32) throws {
        unlinkCallCount += 1
    }
}

private struct POSIXItemKey: Hashable {

    // MARK: - Private Properties

    private let name: String
    private let parentDescriptor: Int32

    // MARK: - Initializer

    init(_ parentDescriptor: Int32, _ name: String) {
        self.parentDescriptor = parentDescriptor
        self.name = name
    }
}

private func directoryInfo(device: dev_t, inode: ino_t, blocks: blkcnt_t = 0) -> Darwin.stat {
    var info = Darwin.stat()
    info.st_dev = device
    info.st_ino = inode
    info.st_mode = mode_t(S_IFDIR)
    info.st_blocks = blocks
    return info
}

private func fileInfo(device: dev_t, inode: ino_t, blocks: blkcnt_t) -> Darwin.stat {
    var info = Darwin.stat()
    info.st_dev = device
    info.st_ino = inode
    info.st_mode = mode_t(S_IFREG)
    info.st_blocks = blocks
    return info
}

private extension Array {

    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
