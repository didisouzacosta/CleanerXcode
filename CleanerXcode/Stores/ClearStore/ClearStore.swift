//
//  ClearStore.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class ClearStore {
    
    // MARK: - Private Variables
    
    private let shellScripCommander = ShellScriptCommander()
    private let preferences: Preferences
    
    // MARK: - Initializers
    
    init(_ preferences: Preferences) {
        self.preferences = preferences
    }
    
    // MARK: - Public Methods
    
    func clear() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #if !DEBUG
        try await shellScripCommander.execute(.removeDerivedData)
        #endif
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
}

extension EnvironmentValues {
    
    @Entry var clearStore = ClearStore(.init())
    
}
