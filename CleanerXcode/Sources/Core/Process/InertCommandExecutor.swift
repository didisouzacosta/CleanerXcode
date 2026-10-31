//
//  InertCommandExecutor.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Used while the app hosts unit tests: it never runs a script or touches the disk.
final class InertCommandExecutor: CommandExecutor {

    // MARK: - Public Properties

    var isCancelled: Bool {
        true
    }

    func run(_ command: Command) throws -> String? {
        nil
    }

    func cancel() {}

}
