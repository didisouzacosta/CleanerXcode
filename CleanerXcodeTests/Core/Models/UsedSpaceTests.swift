import Foundation
import Testing

@testable import CleanerXcode

struct UsedSpaceTests {

    // MARK: - Public Methods

    @Test
    func aggregatesByteCountsIncludingCocoaPodsCache() {
        let space = UsedSpace(
            1,
            archives: 2,
            simulatorData: 3,
            xcodeCache: 5,
            carthageCache: 7,
            cocoaPodsCache: 11,
            deviceSupportIOS: 13,
            deviceSupportWatchOS: 17,
            deviceSupportTvOS: 19
        )

        #expect(space.cache == 23)
        #expect(space.deviceSupport == 49)
        #expect(space.totalSize == 78)
    }

    @Test
    func decodesLegacyDuKilobytesAsBytes() throws {
        let data = Data("""
        {
          "derived_data": 2,
          "archives": 3,
          "simulator_data": 5,
          "xcode_cache": 7,
          "carthage_cache": 11,
          "cocoapods_cache": 13,
          "device_support_ios": 17,
          "device_support_watchos": 19,
          "device_support_tvos": 23
        }
        """.utf8)

        let space = try JSONDecoder().decode(UsedSpace.self, from: data)

        #expect(space.derivedData == 2_048)
        #expect(space.archives == 3_072)
        #expect(space.cocoaPodsCache == 13_312)
        #expect(space.totalSize == 102_400)
    }

    @Test
    func formatsInt64AsBytes() {
        #expect(Int64(1_024).byteFormatted() == "1 KB")
    }
}
