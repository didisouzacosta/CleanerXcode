import AppKit
import Foundation

enum ProtectedApplication: CaseIterable, Equatable, Sendable {
    case xcode
    case simulator

    // MARK: - Public Properties

    var bundleIdentifier: String {
        switch self {
        case .xcode:
            "com.apple.dt.Xcode"
        case .simulator:
            "com.apple.iphonesimulator"
        }
    }
}

enum ApplicationPreflightError: Error, Equatable, LocalizedError, Sendable {
    case terminationRefused(ProtectedApplication)
    case terminationTimedOut([ProtectedApplication])

    // MARK: - Public Properties

    var errorDescription: String? {
        switch self {
        case .terminationRefused(let application):
            return "The application refused normal termination: \(application.bundleIdentifier)"
        case .terminationTimedOut(let applications):
            let bundleIdentifiers = applications.map(\.bundleIdentifier).joined(separator: ", ")

            return "The applications did not terminate before the timeout: \(bundleIdentifiers)"
        }
    }
}

struct ApplicationWaitPolicy: Equatable, Sendable {

    // MARK: - Public Properties

    let pollInterval: Duration
    let timeout: Duration

    // MARK: - Initializer

    init(_ pollInterval: Duration, timeout: Duration) {
        self.pollInterval = max(.milliseconds(1), pollInterval)
        self.timeout = min(max(.zero, timeout), .seconds(60))
    }
}

protocol TerminableApplication: Sendable {
    var isTerminated: Bool { get }
    func terminate() -> Bool
}

protocol RunningApplicationProviding: Sendable {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [any TerminableApplication]
}

actor ApplicationPreflightService {

    // MARK: - Private Properties

    private let clock: any MonotonicClock
    private let provider: any RunningApplicationProviding
    private let waitPolicy: ApplicationWaitPolicy

    // MARK: - Initializer

    init(
        _ provider: any RunningApplicationProviding = FoundationRunningApplicationProvider(),
        clock: any MonotonicClock = ContinuousMonotonicClock(),
        waitPolicy: ApplicationWaitPolicy = .init(.seconds(1), timeout: .seconds(60))
    ) {
        self.clock = clock
        self.provider = provider
        self.waitPolicy = waitPolicy
    }

    // MARK: - Public Methods

    func runningProtectedApplications() -> [ProtectedApplication] {
        ProtectedApplication.allCases.filter { application in
            !provider.runningApplications(withBundleIdentifier: application.bundleIdentifier).isEmpty
        }
    }

    func terminateProtectedApplications() async throws {
        let runningApplications = ProtectedApplication.allCases.flatMap { protectedApplication in
            provider.runningApplications(withBundleIdentifier: protectedApplication.bundleIdentifier).map {
                RunningProtectedApplication(protectedApplication, application: $0)
            }
        }

        for runningApplication in runningApplications {
            let accepted = runningApplication.application.terminate()

            guard accepted || runningApplication.application.isTerminated else {
                throw ApplicationPreflightError.terminationRefused(runningApplication.protectedApplication)
            }
        }

        guard !runningApplications.isEmpty else {
            return
        }

        let deadline = clock.now() + waitPolicy.timeout
        var pendingApplications = runningApplications

        while clock.now() <= deadline {
            if runningApplications.allSatisfy(\.application.isTerminated) {
                return
            }

            pendingApplications = runningApplications.filter { !$0.application.isTerminated }
            let remaining = deadline - clock.now()

            guard remaining > .zero else {
                break
            }

            try await clock.sleep(for: min(waitPolicy.pollInterval, remaining))
        }

        let unterminatedApplications = pendingApplications.map(\.protectedApplication)
        throw ApplicationPreflightError.terminationTimedOut(unterminatedApplications)
    }
}

private struct RunningProtectedApplication: Sendable {

    // MARK: - Public Properties

    let protectedApplication: ProtectedApplication
    let application: any TerminableApplication

    // MARK: - Initializer

    init(_ protectedApplication: ProtectedApplication, application: any TerminableApplication) {
        self.protectedApplication = protectedApplication
        self.application = application
    }
}

struct FoundationRunningApplicationProvider: RunningApplicationProviding {

    // MARK: - Public Methods

    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [any TerminableApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).map {
            FoundationTerminableApplication($0)
        }
    }
}

private final class FoundationTerminableApplication: TerminableApplication, @unchecked Sendable {

    // MARK: - Public Properties

    var isTerminated: Bool {
        application.isTerminated
    }

    // MARK: - Private Properties

    private let application: NSRunningApplication

    // MARK: - Initializer

    init(_ application: NSRunningApplication) {
        self.application = application
    }

    // MARK: - Public Methods

    func terminate() -> Bool {
        application.terminate()
    }
}
