//
//  CategorySizeMeasurerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CategorySizeMeasurerTests {

    // MARK: - Private Properties

    private let derivedData = URL(filePath: "/Users/tester/Library/Developer/Xcode/DerivedData/")
    private let xcodeCache = URL(filePath: "/Users/tester/Library/Caches/com.apple.dt.Xcode/")
    private let cocoaPods = URL(filePath: "/Users/tester/Library/Caches/CocoaPods/")
    private let archives = URL(filePath: "/Users/tester/Library/Developer/Xcode/Archives/")

    // MARK: - Public Methods

    @Test
    func sumsTheTargetsOfEachCategoryAndSkipsCategoriesWithoutTargets() async throws {
        let scanner = DiskUsageScannerStub(sizes: [derivedData: 1_000, xcodeCache: 200, cocoaPods: 30])

        var results: [CategorySize] = []

        try await CategorySizeMeasurer(scanner: scanner).measure(makeCategories()) { results.append($0) }

        #expect(Set(results) == [
            CategorySize(categoryID: .removeDerivedData, bytes: 1_000),
            CategorySize(categoryID: .removeCaches, bytes: 230),
            CategorySize(categoryID: .removeArchives, bytes: 0),
        ])
    }

    @Test
    func keepsTheOtherTargetsAndCategoriesWhenOneTargetFails() async throws {
        let scanner = DiskUsageScannerStub(
            sizes: [derivedData: 1_000, xcodeCache: 200, cocoaPods: 30],
            failures: [xcodeCache: .permissionDenied]
        )
        var results: [CleanupCategoryID: CategorySize] = [:]

        try await CategorySizeMeasurer(scanner: scanner).measure(makeCategories()) { results[$0.categoryID] = $0 }

        #expect(results[.removeCaches] == CategorySize(
            categoryID: .removeCaches,
            bytes: 30,
            failure: .permissionDenied
        ))
        #expect(results[.removeDerivedData] == CategorySize(categoryID: .removeDerivedData, bytes: 1_000))
    }

    @Test(.timeLimit(.minutes(1)))
    func measuresTheCategoriesConcurrently() async throws {
        let categories = makeCategories().filter { $0.targets.count == 1 }
        let scanner = DiskUsageScannerStub(barrier: StartBarrier(count: categories.count))

        var deliveredCount = 0

        try await CategorySizeMeasurer(scanner: scanner).measure(categories) { _ in deliveredCount += 1 }

        #expect(deliveredCount == categories.count)
    }

    @Test
    @MainActor
    func deliversEveryResultOnTheCallersActor() async throws {
        let scanner = DiskUsageScannerStub(sizes: [derivedData: 1])

        var deliveredOnMainThread: [Bool] = []

        try await CategorySizeMeasurer(scanner: scanner).measure(makeCategories()) { _ in
            deliveredOnMainThread.append(Thread.isMainThread)
        }

        #expect(deliveredOnMainThread == [true, true, true])
    }

    @Test
    func throwsCancellationErrorAndDeliversNothingWhenCancelled() async throws {
        let measurer = CategorySizeMeasurer(scanner: DiskUsageScannerStub(suspendsUntilCancelled: true))
        let categories = makeCategories()

        let task = Task { () -> (wasCancelled: Bool, deliveredCount: Int) in
            var deliveredCount = 0
            withUnsafeCurrentTask { $0?.cancel() }

            do {
                try await measurer.measure(categories) { _ in deliveredCount += 1 }
                return (false, deliveredCount)
            } catch {
                return (error is CancellationError, deliveredCount)
            }
        }

        let (wasCancelled, deliveredCount) = await task.value

        #expect(wasCancelled)
        #expect(deliveredCount == 0)
    }

    @Test
    func deliversNothingWhenCancelledEvenIfTheScansStillReturn() async throws {
        // The scans ignore cancellation and return at once, so only the measurer can drop the
        // results of a measurement that was already cancelled.
        let measurer = CategorySizeMeasurer(scanner: DiskUsageScannerStub(sizes: [derivedData: 1]))
        let categories = makeCategories()

        let task = Task { () -> (wasCancelled: Bool, deliveredCount: Int) in
            var deliveredCount = 0
            withUnsafeCurrentTask { $0?.cancel() }

            do {
                try await measurer.measure(categories) { _ in deliveredCount += 1 }
                return (false, deliveredCount)
            } catch {
                return (error is CancellationError, deliveredCount)
            }
        }

        let (wasCancelled, deliveredCount) = await task.value

        #expect(wasCancelled)
        #expect(deliveredCount == 0)
    }

    // MARK: - Private Methods

    private func makeCategories() -> [CleanupCategory] {
        [
            category(.removeDerivedData, roots: [derivedData]),
            category(.removeCaches, roots: [xcodeCache, cocoaPods]),
            category(.removeArchives, roots: [archives]),
            category(.removeOldSimulators, roots: []),
        ]
    }

    private func category(_ id: CleanupCategoryID, roots: [URL]) -> CleanupCategory {
        CleanupCategory(
            id: id,
            targets: roots.map { CleanupTarget(root: $0) },
            operation: .removeContents(.delete),
            risk: .safe,
            isEnabledByDefault: true
        )
    }

}
