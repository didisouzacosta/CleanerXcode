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
    private(set) var usedSpace = UsedSpace()
    
    var freeUpSpace: Double {
        enabledCommands.reduce(0) { partial, command in
            partial + size(of: command)
        }.toDouble()
    }
    
    // MARK: - Private Variables
    
    private let shell = Shell()
    private let preferences: Preferences
    private let analytics: AnalyticsRepresentable
    
    private var timer: Timer?
    
    private var enabledCommands: [Shell.Command] {
        [
            preferences.canRemoveArchives,
            preferences.canRemoveCaches,
            preferences.canRemoveDerivedData,
            preferences.canRemoveOldSimulators,
            preferences.canClearDeviceSupport,
            preferences.canClearSimultorData,
            preferences.canResertXcodePreferences
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
        
        defer {
            setupTimer()
            calculateFreeUpSpace()
        }
    }
    
    // MARK: - Public Methods
    
    func cleaner() async throws {
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
            
            steps = steps.filter { $0.status != .failure }
            
            calculateFreeUpSpace()
            analytics.log(.cleaner(enabledCommands))
        }
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Private Methods
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.calculateFreeUpSpace()
        }
    }
    
    private func calculateFreeUpSpace() {
        Task {
            let value = try? await shell.execute(.calculateFreeUpSpace)
            usedSpace = (try? value?.data(using: .utf8)?.decoder()) ?? .init()
        }
    }
    
}

extension ClearStore {
    
    func size(of command: Shell.Command) -> Int {
        switch command {
        case .removeArchives: usedSpace.archives
        case .removeCaches: usedSpace.cache
        case .removeDerivedData: usedSpace.derivedData
        case .clearDeviceSupport: usedSpace.deviceSupport
        case .clearSimulatorData: usedSpace.simulatorData
        default: 0
        }
    }
    
}

extension EnvironmentValues {
    
    @Entry var clearStore = ClearStore(
        .init(),
        analytics: Analytics()
    )
    
}
