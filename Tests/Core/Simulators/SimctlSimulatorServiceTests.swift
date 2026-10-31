//
//  SimctlSimulatorServiceTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct SimctlSimulatorServiceTests {

    // MARK: - Private Properties

    private let listDevices = ["simctl", "list", "--json", "devices"]
    private let listRuntimes = ["simctl", "runtime", "list", "--json"]
    private let booted = "AAAA0000-0000-0000-0000-000000000001"
    private let shutdown = "AAAA0000-0000-0000-0000-000000000002"

    private var shutdownFolder: URL {
        URL(filePath: "/Users/qa/Library/Developer/CoreSimulator/Devices/\(shutdown)/data").deletingLastPathComponent()
    }

    // MARK: - Public Methods

    @Test
    func listsTheDevicesOfTheDefaultSetWithTheirSizeRuntimeAndState() async throws {
        let runner = ProcessRunnerSpy(responses: [listDevices: .success(SimctlFixtures.devices)])
        let service = makeService(runner: runner)

        let devices = try await service.listDevices(in: .default)
        let first = try #require(devices.first { $0.udid == booted })
        let iPad = try #require(devices.first { $0.name == "iPad Air" })

        #expect(devices.count == 3)
        #expect(first.name == "iPhone 18 Pro")
        #expect(first.deviceTypeIdentifier == "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro")
        #expect(first.runtimeIdentifier == "com.apple.CoreSimulator.SimRuntime.iOS-27-2")
        #expect(first.state == .booted)
        #expect(first.isAvailable)
        #expect(first.sizeBytes == 7_115_542_528 + 675_840)
        #expect(first.lastUsedAt == Date(timeIntervalSince1970: 1_793_382_519))
        #expect(iPad.state == .shutdown)
        #expect(!iPad.isAvailable)
        #expect(iPad.sizeBytes == 1_024)
        #expect(runner.requests == [ProcessRequest.xcrun(listDevices)])
    }

    @Test
    func measuresTheDeviceFolderWhenSimctlReportsNoSize() async throws {
        let service = makeService(
            runner: ProcessRunnerSpy(responses: [listDevices: .success(SimctlFixtures.devices)]),
            scanner: DiskUsageScannerStub(sizes: [shutdownFolder: 4_096])
        )

        let devices = try await service.listDevices(in: .default)

        #expect(devices.first { $0.udid == shutdown }?.sizeBytes == 4_096)
        #expect(devices.first { $0.udid == shutdown }?.lastUsedAt == nil)
    }

    @Test
    func aFolderThatCannotBeMeasuredCountsZero() async throws {
        let service = makeService(
            runner: ProcessRunnerSpy(responses: [listDevices: .success(SimctlFixtures.devices)]),
            scanner: DiskUsageScannerStub(failures: [shutdownFolder: .permissionDenied])
        )

        let devices = try await service.listDevices(in: .default)

        #expect(devices.first { $0.udid == shutdown }?.sizeBytes == 0)
    }

    @Test
    func aCancelledMeasurementCancelsTheListing() async throws {
        let runner = ProcessRunnerSpy(responses: [listDevices: .success(SimctlFixtures.devices)])
        let cancelledScan = makeService(
            runner: runner,
            scanner: DiskUsageScannerStub(failures: [shutdownFolder: .cancelled])
        )
        // The scan ignores cancellation and still returns, so the listing must check by itself.
        let ignoringScan = makeService(runner: runner, scanner: DiskUsageScannerStub(sizes: [shutdownFolder: 1]))

        await #expect(throws: CancellationError.self) {
            try await cancelledScan.listDevices(in: .default)
        }

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ignoringScan.listDevices(in: .default)
        }

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test
    func passesACustomDeviceSetBeforeTheSubcommand() async throws {
        let set = URL(filePath: "/Users/tester/Library/Developer/XCTestDevices", directoryHint: .isDirectory)
        let setArguments = ["simctl", "--set", "/Users/tester/Library/Developer/XCTestDevices/"]
        let runner =
            ProcessRunnerSpy(responses: [setArguments + ["list", "--json", "devices"]: .success(#"{"devices":{}}"#)])

        _ = try await makeService(runner: runner).listDevices(in: .custom(set))
        try await makeService(runner: runner).deleteAllDevices(in: .custom(set))

        #expect(runner.arguments == [
            setArguments + ["list", "--json", "devices"],
            setArguments + ["delete", "all"],
        ])
    }

    @Test
    func listsTheRuntimesWithSizeAndWhetherTheyCanBeDeleted() async throws {
        let runner = ProcessRunnerSpy(responses: [listRuntimes: .success(SimctlFixtures.runtimes)])

        let runtimes = try await makeService(runner: runner).listRuntimes()
        let iOS = try #require(runtimes.first { $0.version == "27.1" })
        let visionOS = try #require(runtimes.first { $0.version == "26.0" })

        #expect(runtimes.count == 2)
        #expect(iOS.identifier == "BBBB0000-0000-0000-0000-000000000001")
        #expect(iOS.runtimeIdentifier == "com.apple.CoreSimulator.SimRuntime.iOS-27-1")
        #expect(iOS.build == "24A94425")
        #expect(iOS.platformIdentifier == "com.apple.platform.iphonesimulator")
        #expect(iOS.sizeBytes == 7_874_743_137)
        #expect(iOS.isDeletable)
        #expect(iOS.lastUsedAt != nil)
        #expect(iOS.state == "Ready")
        #expect(iOS.kind == "Patchable Cryptex Disk Image")
        #expect(visionOS.kind == "Bundled with Xcode")
        #expect(!visionOS.isDeletable)
        #expect(visionOS.lastUsedAt == nil)
        #expect(runner.arguments == [listRuntimes])
    }

    @Test
    func deletingShutsDownTheBootedDevicesFirstAndThenDeletesTheExactUDIDs() async throws {
        let runner = ProcessRunnerSpy(responses: [listDevices: .success(SimctlFixtures.devices)])
        let service = makeService(runner: runner)
        let devices = try await service.listDevices(in: .default).filter { $0.udid == booted || $0.udid == shutdown }

        try await service.delete(devices, in: .default)

        #expect(runner.arguments.dropFirst() == [
            ["simctl", "shutdown", booted],
            ["simctl", "delete", booted, shutdown],
        ])
    }

    @Test
    func deletingNothingRunsNothing() async throws {
        let runner = ProcessRunnerSpy()

        try await makeService(runner: runner).delete([], in: .default)

        #expect(runner.requests.isEmpty)
    }

    @Test
    func runsEachMaintenanceCommandWithItsArgumentsAndTimeout() async throws {
        let runner = ProcessRunnerSpy()
        let service = makeService(runner: runner)

        try await service.shutdownAll(in: .default)
        try await service.deleteUnavailable()
        try await service.eraseAll()
        try await service.deleteRuntime(identifier: "BBBB0000-0000-0000-0000-000000000001")

        #expect(runner.requests == [
            ProcessRequest.xcrun(["simctl", "shutdown", "all"]),
            ProcessRequest.xcrun(["simctl", "delete", "unavailable"]),
            ProcessRequest.xcrun(["simctl", "erase", "all"], timeout: ProcessRequest.eraseAllTimeout),
            ProcessRequest.xcrun(
                ["simctl", "runtime", "delete", "BBBB0000-0000-0000-0000-000000000001"],
                timeout: ProcessRequest.runtimeDeleteTimeout
            ),
        ])
    }

    @Test
    func reportsTheToolsAsUnavailableWhenXcrunCannotFindSimctl() async throws {
        let missingSimctl = ProcessRunnerSpy(responses: [
            listDevices: .failure(.commandFailed(
                exitCode: 72,
                summary: "xcrun: error: unable to find utility \"simctl\""
            )),
        ])
        let missingXcrun = ProcessRunnerSpy(responses: [listDevices: .failure(.toolUnavailable)])
        // Xcode deleted while still selected, or a missing developer directory: xcrun exits 1.
        let missingXcode = ProcessRunnerSpy(responses: [
            listDevices: .failure(.commandFailed(
                exitCode: 1,
                summary: "xcrun: error: invalid active developer path (/Applications/Xcode.app/Contents/Developer)"
            )),
        ])

        await #expect(throws: CleanupError.toolUnavailable) {
            try await makeService(runner: missingSimctl).listDevices(in: .default)
        }

        await #expect(throws: CleanupError.toolUnavailable) {
            try await makeService(runner: missingXcrun).listDevices(in: .default)
        }

        await #expect(throws: CleanupError.toolUnavailable) {
            try await makeService(runner: missingXcode).listDevices(in: .default)
        }
    }

    @Test
    func keepsOtherCommandFailuresAndReportsUnreadableJSON() async throws {
        let failing = ProcessRunnerSpy(responses: [
            ["simctl", "erase", "all"]: .failure(.commandFailed(exitCode: 149, summary: "Unable to erase")),
        ])
        let garbled = ProcessRunnerSpy(responses: [listDevices: .success("{ not json")])

        await #expect(throws: CleanupError.commandFailed(exitCode: 149, summary: "Unable to erase")) {
            try await makeService(runner: failing).eraseAll()
        }

        await #expect(throws: SimctlSimulatorService.unreadableOutput) {
            try await makeService(runner: garbled).listDevices(in: .default)
        }
    }

    @Test
    func restartingTheServiceDelegatesToTheRestarter() throws {
        let restarter = ServiceRestarterSpy()

        try makeService(runner: ProcessRunnerSpy(), restarter: restarter).restartService()

        #expect(restarter.restartCount == 1)
    }

    // MARK: - Private Methods

    private func makeService(
        runner: ProcessRunnerSpy,
        scanner: DiskUsageScannerStub = DiskUsageScannerStub(),
        restarter: ServiceRestarterSpy = ServiceRestarterSpy()
    ) -> SimctlSimulatorService {
        SimctlSimulatorService(runner: runner, scanner: scanner, restarter: restarter)
    }

}
