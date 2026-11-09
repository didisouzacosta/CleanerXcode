//
//  DemoCleanupExecutor.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    import Foundation

    /// Cleans the demo's disk category by category, with a short pause each, so the progress shows,
    /// section by section as the storyboard does: Xcode, Simulators, Temporary files, then User data.
    /// It never touches a file, a simulator nor the Trash.
    struct DemoCleanupExecutor: CleanupExecuting {

        // MARK: - Public Properties

        static let recordingStepDelay: Duration = .milliseconds(900)

        let state: DemoDiskState
        let stepDelay: Duration

        // MARK: - Private Properties

        private var homePath: String {
            CleanupLocations.inert.home.path(percentEncoded: false)
        }

        // MARK: - Initializers

        init(state: DemoDiskState, stepDelay: Duration = recordingStepDelay) {
            self.state = state
            self.stepDelay = stepDelay
        }

        // MARK: - Private Static Methods

        /// Stable: within a section the catalog order stays.
        private static func sectionOrder(_ categories: [CleanupCategory]) -> [CleanupCategory] {
            let sections = CleanerSection.allCases

            func rank(_ category: CleanupCategory) -> Int {
                sections.firstIndex { $0.categoryIDs.contains(category.id) } ?? sections.count
            }

            return categories.enumerated()
                .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
                .map(\.element)
        }

        // MARK: - Public Methods

        func execute(_ plan: CleanupPlan, onEvent: @escaping (CleanupEvent) -> Void) async -> CleanupReport {
            var results: [CleanupItemResult] = []

            for category in Self.sectionOrder(plan.categories) {
                guard !Task.isCancelled else { return CleanupReport(results: results, wasCancelled: true) }

                onEvent(.categoryStarted(category.id))

                do {
                    try await Task.sleep(for: stepDelay)
                } catch {
                    return CleanupReport(results: results, wasCancelled: true)
                }

                for target in category.targets {
                    let result = clean(target, of: category)

                    onEvent(.itemFinished(result))
                    results.append(result)
                }
            }

            return CleanupReport(results: results)
        }

        // MARK: - Private Methods

        private func clean(_ target: CleanupTarget, of category: CleanupCategory) -> CleanupItemResult {
            let bytes = state.clean(target)
            let outcome: CleanupItemResult.Outcome = switch (bytes, category.operation) {
            case (0, _): .skipped(.notFound)
            case (_, .removeContents(.trash)): .trashed
            default: .removed
            }

            return CleanupItemResult(
                categoryID: category.id,
                displayPath: displayPath(of: target),
                bytes: bytes,
                outcome: outcome
            )
        }

        /// `~/…` from the inert home, as the real executor shows paths.
        private func displayPath(of target: CleanupTarget) -> String {
            var path = target.root.path(percentEncoded: false)
            var home = homePath

            while path.hasSuffix("/") {
                path.removeLast()
            }

            while home.hasSuffix("/") {
                home.removeLast()
            }

            guard path.hasPrefix(home) else { return path }

            return "~" + path.dropFirst(home.count)
        }

    }
#endif
