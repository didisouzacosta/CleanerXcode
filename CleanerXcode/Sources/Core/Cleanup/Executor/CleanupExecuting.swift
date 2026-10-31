//
//  CleanupExecuting.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

protocol CleanupExecuting {
    /// Never throws: a cancelled run returns a `.cancelled` report with what was already freed.
    func execute(_ plan: CleanupPlan, onEvent: @escaping (CleanupEvent) -> Void) async -> CleanupReport
}

extension CleanupExecutor: CleanupExecuting {}
