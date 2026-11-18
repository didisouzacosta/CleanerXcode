//
//  DemoDiskState.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    import Foundation
    import Synchronization

    /// The demo's make-believe disk (C36): a size for each folder of `CleanupLocations.inert`,
    /// matched by the end of its path, that drops to its leftover once the demo cleans it. Nothing
    /// reads nor writes this Mac's disk.
    ///
    /// The nonisolated scanner reads it from the measurement's tasks while the main-actor executor
    /// cleans it, so the sizes live in a `Mutex`: every access is synchronous and nothing suspends
    /// inside `withLock`, so the lock is never held across an `await`.
    nonisolated final class DemoDiskState: Sendable {

        // MARK: - Public Properties

        /// The storyboard on Figma page "09 · Demo", in the order the demo measures them: 87.7 GB
        /// found with the unavailable simulators, 44.6 GB to free once Archives is picked, and
        /// 12 MB of Xcode and 6 MB of simulators back after the cleanup. The orphan simulator
        /// folders are measured by the `FilteredContentsMeasurer` over the inert temporary folder,
        /// which does not exist, so they read Zero kB and their share sits in the CoreSimulator
        /// caches.
        static let recordingEntries: [Entry] = [
            Entry(suffix: "Xcode/DerivedData", bytes: 33_800_000_000, leftover: 12_000_000),
            Entry(suffix: "Caches/com.apple.dt.Xcode", bytes: 900_000_000),
            Entry(suffix: "Caches/com.apple.dt.xcodebuild", bytes: 200_000_000),
            Entry(suffix: "Caches/CocoaPods", bytes: 300_000_000),
            Entry(suffix: "Xcode/Archives", bytes: 4_200_000_000),
            Entry(suffix: "Xcode/iOS DeviceSupport", bytes: 6_400_000_000),
            Entry(suffix: "CoreSimulator/Devices", bytes: 31_000_000_000),
            Entry(suffix: "Developer/XCTestDevices", bytes: 900_000_000),
            Entry(suffix: "UserData/Previews", bytes: 1_100_000_000),
            Entry(suffix: "UserData/IB Support", bytes: 100_000_000),
            Entry(suffix: "Developer/XCPGDevices", bytes: 100_000_000),
            Entry(suffix: "CoreSimulator/Caches", bytes: 2_400_000_000, leftover: 6_000_000),
            Entry(suffix: "CoreSimulator/Temp", bytes: 200_000_000),
            Entry(suffix: "Logs/CoreSimulator", bytes: 400_000_000),
            Entry(suffix: "Caches/org.swift.swiftpm", bytes: 3_500_000_000),
            Entry(suffix: "Xcode/Products", bytes: 12_000_000),
            Entry(suffix: "Xcode/UserData", bytes: 588_000_000),
        ]

        // MARK: - Private Properties

        private let entries: [Entry]
        private let remaining: Mutex<[String: Int64]>

        // MARK: - Initializers

        init(entries: [Entry] = recordingEntries) {
            self.entries = entries
            self.remaining = Mutex(Dictionary(entries.map { ($0.suffix, $0.bytes) }) { first, _ in first })
        }

        // MARK: - Public Methods

        func size(of target: CleanupTarget) -> Int64 {
            guard let suffix = suffix(of: target) else { return 0 }

            return remaining.withLock { $0[suffix] ?? 0 }
        }

        /// The position of the target's entry, so the demo can measure them one after another.
        func order(of target: CleanupTarget) -> Int? {
            guard let suffix = suffix(of: target) else { return nil }

            return entries.firstIndex { $0.suffix == suffix }
        }

        /// Empties the target, returns what it held, and leaves what grows back right away, as
        /// Xcode and the simulators write again soon after a cleanup.
        func clean(_ target: CleanupTarget) -> Int64 {
            guard let suffix = suffix(of: target) else { return 0 }

            let leftover = entries.first { $0.suffix == suffix }?.leftover ?? 0

            return remaining.withLock { sizes in
                let bytes = sizes[suffix] ?? 0

                sizes[suffix] = bytes > 0 ? leftover : 0

                return bytes
            }
        }

        // MARK: - Private Methods

        private func suffix(of target: CleanupTarget) -> String? {
            var path = target.root.path(percentEncoded: false)

            while path.count > 1, path.hasSuffix("/") {
                path.removeLast()
            }

            return entries.first { path.hasSuffix("/" + $0.suffix) }?.suffix
        }

        // MARK: - Nested Types

        struct Entry: Sendable, Hashable {

            // MARK: - Public Properties

            /// The last components of a target's root, such as `Xcode/DerivedData`.
            let suffix: String
            let bytes: Int64
            /// What the folder holds again after the demo cleans it.
            let leftover: Int64

            // MARK: - Initializers

            init(suffix: String, bytes: Int64, leftover: Int64 = 0) {
                self.suffix = suffix
                self.bytes = bytes
                self.leftover = leftover
            }

        }

    }
#endif
