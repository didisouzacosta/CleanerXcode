//
//  CommandExecutorStub.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 23/03/25.
//

@testable import CleanerXcode

final class CommandExecutorStub: CommandExecutor {

    // MARK: - Public Properties

    var result: String?
    var responses: [String: String] = [:]
    var failingScripts: Set<String> = []
    var isCancelled = false

    // MARK: - Public Methods

    @discardableResult
    func run(_ command: Command) throws -> String? {
        if failingScripts.contains(command.script) {
            throw "Stubbed failure for \(command.script)"
        }

        return responses[command.script] ?? result
    }

    func cancel() {
        isCancelled = true
    }

}
