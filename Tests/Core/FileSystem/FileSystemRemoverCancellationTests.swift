//
//  FileSystemRemoverCancellationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct FileSystemRemoverCancellationTests {

    // MARK: - Private Properties

    /// Kept as a suite property so the folder lives until the test ends.
    private let fixture: TemporaryDirectoryFixture

    // MARK: - Initializers

    init() throws {
        fixture = try TemporaryDirectoryFixture()
    }

    // MARK: - Public Methods

    /// A filter that reads the disk must not delay or swallow a cancellation.
    @Test
    func checksForCancellationBeforeEachFilterCall() async throws {
        let root = try fixture.makeDirectory("tmp")

        for name in ["a", "b", "c"] {
            try fixture.makeFile("tmp/\(name)", bytes: 1)
        }

        let calls = CleanupResultCollector()
        let remover = FileSystemRemover(
            policy: SafePathPolicy(roots: [root], protectedPaths: [], allowedBases: [fixture.url]),
            locations: CleanupLocations(
                home: fixture.url,
                userTemporary: root,
                systemTemporary: root,
                varTemporary: root
            )
        )

        let task = Task {
            try await remover.removeContents(
                of: CleanupTarget(root: root),
                categoryID: .clearTemporaryFiles,
                mode: .delete,
                filter: { url in
                    calls.append(CleanupItemResult(
                        categoryID: .clearTemporaryFiles,
                        displayPath: url.lastPathComponent,
                        bytes: 0,
                        outcome: .removed
                    ))
                    withUnsafeCurrentTask { $0?.cancel() }
                    return false
                },
                onResult: { _ in }
            )
        }

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(calls.results.count == 1)
    }

}
