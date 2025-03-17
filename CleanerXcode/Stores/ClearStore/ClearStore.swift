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
    
    private let shell = Shell()
    private let preferences: Preferences
    private let analytics: AnalyticsRepresentable
    
    private var enabledCommands: [Shell.Command] {
        [
            preferences.canRemoveArchives,
            preferences.canRemoveCaches,
            preferences.canRemoveDerivedData,
            preferences.canRemoveDeviceSupport,
            preferences.canRemoveOldSimulators,
            preferences.canRemoveSimultorData,
            preferences.canResertXcode
        ]
        .filter { $0.value }
        .compactMap {
            .init(rawValue: $0.key)
        }
    }
    
    // MARK: - Initializers
    
    init(
        _ preferences: Preferences,
        analytics: AnalyticsRepresentable
    ) {
        self.preferences = preferences
        self.analytics = analytics
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
                        try await self?.shell.execute(command)
                        return .init(command.id, status: .success)
                    } catch {
                        return .init(command.id, status: .failure)
                    }
                }
            }
            
            while let value = await group.next() {
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / 2))
                
                if let index = steps.firstIndex(where: { $0.id == value.id }) {
                    steps[index] = value
                }
            }
            
            analytics.log(.clear(enabledCommands))
        }
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
}

extension EnvironmentValues {
    
    @Entry var clearStore = ClearStore(
        .init(),
        analytics: Analytics()
    )
    
}
