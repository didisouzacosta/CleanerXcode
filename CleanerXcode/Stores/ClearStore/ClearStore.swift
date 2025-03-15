//
//  ClearStore.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

struct Step: Identifiable, Hashable {
    
    enum Status {
        case waiting
        case working
        case success
        case failure
        
        var color: Color {
            switch self {
            case .waiting: .white.opacity(0.3)
            case .working: .blue
            case .success: .white
            case .failure: .red
            }
        }
    }
    
    let id: String
    let status: Status
    
    init(_ id: String, status: Status) {
        self.id = id
        self.status = status
    }
    
}

@Observable
final class ClearStore {
    
    // MARK: - Public Variables
    
    private(set) var steps = [Step]()
    
    // MARK: - Private Variables
    
    private let shellScripCommander = ShellScript()
    private let preferences: Preferences
    
    private var enabledCommands: [ShellScript.Command] {
        [
            preferences.canRemoveDerivedData,
            preferences.canRemoveCaches,
            preferences.canRemoveDeviceSupport,
            preferences.canRemoveOldSimulators
        ]
        .filter { $0.value }
        .compactMap {
            .init(rawValue: $0.key)
        }
    }
    
    // MARK: - Initializers
    
    init(_ preferences: Preferences) {
        self.preferences = preferences
    }
    
    // MARK: - Public Methods
    
    func clear() async throws {
        steps = enabledCommands.map { command in
            .init(command.id, status: .waiting)
        }
        
        await withTaskGroup(of: Step.self) { group in
            enabledCommands.enumerated().forEach { index, command in
                group.addTask(priority: .background) { [weak self] in
                    do {
                        try await self?.shellScripCommander.execute(command)
                        return .init(command.id, status: .success)
                    } catch {
                        return .init(command.id, status: .failure)
                    }
                }
            }
            
            while let value = await group.next() {
                if let index = steps.firstIndex(where: { $0.id == value.id }) {
                    steps[index] = value
                }
            }
        }
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
}

extension EnvironmentValues {
    
    @Entry var clearStore = ClearStore(.init())
    
}
