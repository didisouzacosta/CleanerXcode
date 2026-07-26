import Foundation
import Testing

@testable import CleanerXcode

struct ApplicationPreflightServiceTests {

    // MARK: - Public Methods

    @Test
    func detectsXcodeAndSimulatorByExactBundleIdentifiers() async {
        let xcode = RunningApplicationFake(.xcode)
        let simulator = RunningApplicationFake(.simulator)
        let provider = RunningApplicationProviderFake([
            ProtectedApplication.xcode.bundleIdentifier: [xcode],
            ProtectedApplication.simulator.bundleIdentifier: [simulator]
        ])
        let service = ApplicationPreflightService(provider)

        let runningApplications = await service.runningProtectedApplications()

        #expect(runningApplications == [.xcode, .simulator])
        #expect(provider.requestedBundleIdentifiers == [
            "com.apple.dt.Xcode",
            "com.apple.iphonesimulator"
        ])
    }

    @Test
    func succeedsWithoutTerminationCallsWhenAppsAreAbsent() async throws {
        let provider = RunningApplicationProviderFake([:])
        let service = ApplicationPreflightService(provider)

        try await service.terminateProtectedApplications()

        #expect(provider.requestedBundleIdentifiers.count == 2)
    }

    @Test
    func waitsUntilAcceptedTerminationsComplete() async throws {
        let xcode = RunningApplicationFake(.xcode)
        let clock = AdvancingMonotonicClock {
            xcode.markTerminated()
        }
        let provider = RunningApplicationProviderFake([
            ProtectedApplication.xcode.bundleIdentifier: [xcode]
        ])
        let service = ApplicationPreflightService(
            provider,
            clock: clock,
            waitPolicy: .init(.milliseconds(1), timeout: .seconds(1))
        )

        try await service.terminateProtectedApplications()

        #expect(xcode.terminateCount == 1)
        #expect(clock.sleepCount == 1)
    }

    @Test
    func treatsAFalseTerminationResultAsSuccessWhenTheAppAlreadyExited() async throws {
        let xcode = RunningApplicationFake(
            .xcode,
            acceptsTermination: false,
            terminatesDuringRequest: true
        )
        let clock = AdvancingMonotonicClock()
        let provider = RunningApplicationProviderFake([
            ProtectedApplication.xcode.bundleIdentifier: [xcode]
        ])
        let service = ApplicationPreflightService(provider, clock: clock)

        try await service.terminateProtectedApplications()

        #expect(xcode.terminateCount == 1)
        #expect(clock.sleepCount == 0)
    }

    @Test
    func reportsARefusedNormalTerminationWhenTheAppRemainsLive() async {
        let xcode = RunningApplicationFake(.xcode, acceptsTermination: false)
        let clock = AdvancingMonotonicClock()
        let provider = RunningApplicationProviderFake([
            ProtectedApplication.xcode.bundleIdentifier: [xcode]
        ])
        let service = ApplicationPreflightService(provider, clock: clock)

        do {
            try await service.terminateProtectedApplications()
            Issue.record("Expected normal termination to be refused.")
        } catch let error as ApplicationPreflightError {
            #expect(error == .terminationRefused(.xcode))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(xcode.terminateCount == 1)
        #expect(clock.sleepCount == 0)
    }

    @Test
    func capsEveryConfiguredDeadlineAtSixtySeconds() {
        let policy = ApplicationWaitPolicy(.seconds(2), timeout: .seconds(120))

        #expect(policy.pollInterval == .seconds(2))
        #expect(policy.timeout == .seconds(60))
    }

    @Test
    func reportsTimeoutAtTheMonotonicDeadlineWithoutForceTermination() async {
        let simulator = RunningApplicationFake(.simulator)
        let clock = AdvancingMonotonicClock()
        let provider = RunningApplicationProviderFake([
            ProtectedApplication.simulator.bundleIdentifier: [simulator]
        ])
        let service = ApplicationPreflightService(provider, clock: clock)

        do {
            try await service.terminateProtectedApplications()
            Issue.record("Expected normal termination to time out.")
        } catch let error as ApplicationPreflightError {
            #expect(error == .terminationTimedOut([.simulator]))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(simulator.terminateCount == 1)
        #expect(clock.sleepCount == 60)
        #expect(clock.now() == .seconds(60))
        #expect(!simulator.isTerminated)
    }

    @Test
    func doesNotAcceptTerminationObservedOnlyAfterADeadlineOvershoot() async {
        let xcode = RunningApplicationFake(.xcode)
        let clock = AdvancingMonotonicClock(.seconds(1)) {
            xcode.markTerminated()
        }
        let provider = RunningApplicationProviderFake([
            ProtectedApplication.xcode.bundleIdentifier: [xcode]
        ])
        let service = ApplicationPreflightService(
            provider,
            clock: clock,
            waitPolicy: .init(.seconds(60), timeout: .seconds(60))
        )

        do {
            try await service.terminateProtectedApplications()
            Issue.record("Expected the overshot deadline to time out.")
        } catch let error as ApplicationPreflightError {
            #expect(error == .terminationTimedOut([.xcode]))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(clock.now() == .seconds(61))
        #expect(clock.sleepCount == 1)
    }
}

private final class RunningApplicationProviderFake: RunningApplicationProviding, @unchecked Sendable {

    // MARK: - Public Properties

    var requestedBundleIdentifiers: [String] {
        lock.withLock { storedRequestedBundleIdentifiers }
    }

    // MARK: - Private Properties

    private let applications: [String: [any TerminableApplication]]
    private let lock = NSLock()
    private var storedRequestedBundleIdentifiers = [String]()

    // MARK: - Initializer

    init(_ applications: [String: [any TerminableApplication]]) {
        self.applications = applications
    }

    // MARK: - Public Methods

    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [any TerminableApplication] {
        lock.withLock {
            storedRequestedBundleIdentifiers.append(bundleIdentifier)
        }
        return applications[bundleIdentifier] ?? []
    }
}

private final class RunningApplicationFake: TerminableApplication, @unchecked Sendable {

    // MARK: - Public Properties

    let protectedApplication: ProtectedApplication

    var isTerminated: Bool {
        lock.withLock { storedIsTerminated }
    }

    var terminateCount: Int {
        lock.withLock { storedTerminateCount }
    }

    // MARK: - Private Properties

    private let acceptsTermination: Bool
    private let lock = NSLock()
    private let terminatesDuringRequest: Bool
    private var storedIsTerminated = false
    private var storedTerminateCount = 0

    // MARK: - Initializer

    init(
        _ protectedApplication: ProtectedApplication,
        acceptsTermination: Bool = true,
        terminatesDuringRequest: Bool = false
    ) {
        self.protectedApplication = protectedApplication
        self.acceptsTermination = acceptsTermination
        self.terminatesDuringRequest = terminatesDuringRequest
    }

    // MARK: - Public Methods

    func markTerminated() {
        lock.withLock {
            storedIsTerminated = true
        }
    }

    func terminate() -> Bool {
        lock.withLock {
            storedTerminateCount += 1

            if terminatesDuringRequest {
                storedIsTerminated = true
            }
        }

        return acceptsTermination
    }
}

private final class AdvancingMonotonicClock: MonotonicClock, @unchecked Sendable {

    // MARK: - Public Properties

    var sleepCount: Int {
        lock.withLock { storedSleepCount }
    }

    // MARK: - Private Properties

    private let lock = NSLock()
    private let onSleep: @Sendable () -> Void
    private let overshoot: Duration
    private var instant = Duration.zero
    private var storedSleepCount = 0

    // MARK: - Initializer

    init(
        _ overshoot: Duration = .zero,
        onSleep: @escaping @Sendable () -> Void = {}
    ) {
        self.overshoot = overshoot
        self.onSleep = onSleep
    }

    // MARK: - Public Methods

    func now() -> Duration {
        lock.withLock { instant }
    }

    func sleep(for duration: Duration) async throws {
        lock.withLock {
            storedSleepCount += 1
            instant += duration + overshoot
        }
        onSleep()
    }
}
