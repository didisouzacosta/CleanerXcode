//
//  ProcessRunnerSpy.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Records every request and answers by its exact arguments, so tests check the commands without
/// ever running `simctl`. Unknown arguments succeed with empty output.
nonisolated final class ProcessRunnerSpy: ProcessRunning, Sendable {

    // MARK: - Public Properties

    var requests: [ProcessRequest] {
        state.withLock { $0 }
    }

    var arguments: [[String]] {
        requests.map(\.arguments)
    }

    // MARK: - Private Properties

    private let responses: [[String]: Result<String, CleanupError>]
    private let state = Mutex<[ProcessRequest]>([])

    // MARK: - Initializers

    init(responses: [[String]: Result<String, CleanupError>] = [:]) {
        self.responses = responses
    }

    // MARK: - Public Methods

    func run(_ request: ProcessRequest) throws -> ProcessOutput {
        state.withLock { $0.append(request) }

        let output = try responses[request.arguments, default: .success("")].get()

        return ProcessOutput(standardOutput: Data(output.utf8), standardError: Data())
    }

}
