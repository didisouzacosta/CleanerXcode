//
//  CommandExecutorTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CommandExecutorTests {

    // MARK: - Private Properties

    private let commandExecutor = StubbedCommandExecutor()

    func shouldResponseSuccessfullyWhenTheShellResponseIsDone(_ text: String) throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success(text)

        try stubbedCommand.run(.fake)
    }

    @Test
    func shouldThrowErrorWhenCommandBrokes() throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .failure("Error executing script")

        #expect(throws: Error.self) {
            try stubbedCommand.run(.fake)
        }

        #expect(throws: Error.self) {
            try stubbedCommand.run(.fake)
        }
    }

    @Test
    func shouldResponseSuccessfullyWhenTheShellResponseIsAnything() throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success("Orlando")

        let result = try stubbedCommand.run(.fake)

        #expect(result == "Orlando")
    }

    @Test
    func shouldResponseSuccessDecodableObject() async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success("{\"name\": \"Orlando\"}")

        let person: Person = try await stubbedCommand.runDecoder(.fake)

        #expect(person.name == "Orlando")
    }

}

private final class StubbedCommandExecutor: CommandExecutor {

    // MARK: - Public Properties

    var result: Result = .idle

    var isCancelled: Bool {
        false
    }

    func cancel() {}

    @discardableResult
    func run(_ command: Command) throws -> String? {
        switch result {
        case let .failure(error):
            throw error
        case let .success(success):
            return success
        case .idle:
            return nil
        }
    }

    // MARK: - Nested Types

    enum Result {
        case idle
        case success(String)
        case failure(Error)
    }

}

private extension Command {

    static let fake = Command("fake-command")

}
