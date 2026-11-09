//
//  RuntimeCatalogParserTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Apple's catalog of downloadable runtimes read into the versions the app offers (C35, R2): final
/// cryptex runtimes for this Mac's architecture, one per platform and version, with the variant's size.
struct RuntimeCatalogParserTests {

    // MARK: - Public Methods

    /// AC2: nine entries on Apple silicon, each with the size of its arm64 variant.
    @Test
    func keepsTheFinalRuntimesOfThisArchitectureWithTheirSizes() throws {
        let catalog = try RuntimeCatalogParser.catalog(
            from: SimulatorRuntimeIndexFixture.data(),
            hostArchitecture: "arm64"
        )

        #expect(catalog.entries == [
            entry(.iOS, "27.2", "24B8117", 8_321_588_736),
            entry(.iOS, "27.1", "24A94425", 7_851_823_104),
            entry(.iOS, "26.5", "23F77", 8_522_901_969),
            entry(.iOS, "26.1", "23B86", 8_321_575_375),
            entry(.iOS, "26.0", "23A343", 7_986_028_446),
            entry(.watchOS, "26.5", "23T570", 3_959_483_106),
            entry(.tvOS, "27.2", "24K150", 3_758_154_240),
            entry(.visionOS, "26.4.1", "23O249a", 7_314_935_697),
        ])
        #expect(catalog.refreshInterval == .seconds(86_400))
    }

    /// On an Intel Mac the universal variants win, and the arm64-only 27.x runtimes are left out.
    @Test
    func anIntelMacGetsTheUniversalVariants() throws {
        let catalog = try RuntimeCatalogParser.catalog(
            from: SimulatorRuntimeIndexFixture.data(),
            hostArchitecture: "x86_64"
        )

        #expect(catalog.entries == [
            entry(.iOS, "26.5", "23F77", 10_603_484_383),
            entry(.iOS, "26.1", "23B86", 10_335_047_072),
            entry(.iOS, "26.0", "23A343", 10_066_611_438),
            entry(.watchOS, "26.5", "23T570", 5_234_754_350),
            entry(.visionOS, "26.4.1", "23O249a", 9_395_538_775),
        ])
    }

    /// AC3: the binary form of the same list reads the same.
    @Test
    func theBinaryFormReadsLikeTheXMLForm() throws {
        let xml = try SimulatorRuntimeIndexFixture.data()
        let object = try PropertyListSerialization.propertyList(from: xml, format: nil)
        let binary = try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)

        #expect(binary.prefix(6) == Data("bplist".utf8))
        #expect(
            try RuntimeCatalogParser.catalog(from: binary, hostArchitecture: "arm64")
                == RuntimeCatalogParser.catalog(from: xml, hostArchitecture: "arm64")
        )
    }

    /// AC3: an entry with an unexpected value is left out on its own; the others still read.
    @Test
    func anUnreadableEntryIsLeftOutAlone() throws {
        let data = try plist([
            "downloadables": [
                downloadable(version: "26.5", build: "23F77", size: 8_522_901_969),
                "not a dictionary",
                downloadable(version: "26.2", build: "23C54", size: "8388683973"),
                downloadable(version: "26.3", build: "23D1", architectures: "arm64"),
                downloadable(version: "26.4", build: "23E244", size: 0),
                downloadable(version: "beta", build: "23Z1"),
                downloadable(version: "26.1", build: ""),
            ],
        ])

        let catalog = try RuntimeCatalogParser.catalog(from: data, hostArchitecture: "arm64")

        #expect(catalog.entries == [entry(.iOS, "26.5", "23F77", 8_522_901_969)])
    }

    @Test
    func leavesOutBetasCandidatesPackagesAndRuntimesWithHostRequirements() throws {
        var withRequirements = downloadable(version: "27.1", build: "24A94401")
        withRequirements["hostRequirements"] = ["maxXcodeVersion": "27.1.0"]

        var oddRequirements = downloadable(version: "27.0", build: "24A434")
        oddRequirements["hostRequirements"] = "unexpected"

        var disk = downloadable(version: "25.0", build: "22A1")
        disk["contentType"] = "diskImage"

        var package = downloadable(version: "24.0", build: "21A1")
        package["downloadMethod"] = "package"

        let data = try plist([
            "downloadables": [
                downloadable(version: "26.0", build: "23A5260l", name: "iOS 26.0 beta Simulator Runtime"),
                downloadable(version: "26.2", build: "23C52", name: "iOS 26.2 Release Candidate Simulator Runtime"),
                downloadable(version: "26.3", build: "23D5", name: "iOS 26.3 BETA 2 Simulator Runtime"),
                withRequirements,
                oddRequirements,
                disk,
                package,
                downloadable(version: "26.4", build: "23E1", architectures: ["x86_64"]),
            ],
        ])

        #expect(try RuntimeCatalogParser.catalog(from: data, hostArchitecture: "arm64").entries.isEmpty)
    }

    @Test
    func aMissingOrInvalidRefreshIntervalIsOneDay() throws {
        let missing = try plist(["downloadables": [Any]()])
        let zero = try plist(["downloadables": [Any](), "refreshInterval": 0])
        let text = try plist(["downloadables": [Any](), "refreshInterval": "soon"])
        let twoHours = try plist(["downloadables": [Any](), "refreshInterval": 7_200])

        #expect(try RuntimeCatalogParser.catalog(from: missing, hostArchitecture: "arm64")
            .refreshInterval == .seconds(86_400))
        #expect(try RuntimeCatalogParser.catalog(from: zero, hostArchitecture: "arm64")
            .refreshInterval == .seconds(86_400))
        #expect(try RuntimeCatalogParser.catalog(from: text, hostArchitecture: "arm64")
            .refreshInterval == .seconds(86_400))
        #expect(try RuntimeCatalogParser.catalog(from: twoHours, hostArchitecture: "arm64")
            .refreshInterval == .seconds(7_200))
    }

    /// AC3: anything but a list of downloadables is malformed.
    @Test(arguments: [
        Data("not a property list".utf8),
        Data(),
        Data(#"{"downloadables": []}"#.utf8),
    ])
    func garbageIsMalformed(data: Data) {
        #expect(throws: RuntimeCatalogError.malformed) {
            try RuntimeCatalogParser.catalog(from: data, hostArchitecture: "arm64")
        }
    }

    @Test
    func aListWithoutDownloadablesIsMalformed() throws {
        let withoutDownloadables = try plist(["version": "2", "refreshInterval": 86_400])
        let wrongType = try plist(["downloadables": "none"])

        #expect(throws: RuntimeCatalogError.malformed) {
            try RuntimeCatalogParser.catalog(from: withoutDownloadables, hostArchitecture: "arm64")
        }
        #expect(throws: RuntimeCatalogError.malformed) {
            try RuntimeCatalogParser.catalog(from: wrongType, hostArchitecture: "arm64")
        }
    }

    @Test
    func theHostArchitectureIsThisMacs() {
        #if arch(arm64)
            #expect(RuntimeCatalogParser.hostArchitecture == "arm64")
        #else
            #expect(RuntimeCatalogParser.hostArchitecture == "x86_64")
        #endif
    }

    // MARK: - Private Methods

    private func entry(
        _ platform: RuntimePlatform,
        _ version: String,
        _ build: String,
        _ size: Int64
    ) -> RuntimeCatalogEntry? {
        RuntimeBuildVersion(version).map {
            RuntimeCatalogEntry(platform: platform, version: $0, build: build, sizeBytes: size)
        }
    }

    private func downloadable(
        version: String,
        build: String,
        size: Any = 8_000_000_000,
        architectures: Any = ["arm64"],
        name: String? = nil
    ) -> [String: Any] {
        [
            "name": name ?? "iOS \(version) Simulator Runtime",
            "platform": "com.apple.platform.iphoneos",
            "contentType": "cryptexDiskImage",
            "downloadMethod": "mobileAsset",
            "architectures": architectures,
            "fileSize": size,
            "simulatorVersion": ["version": version, "buildUpdate": build],
        ]
    }

    private func plist(_ object: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
    }

}
