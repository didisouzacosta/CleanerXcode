//
//  CleanerStore.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class CleanerStore {
    
    // MARK: - Public Variables
    
    private(set) var usedSpace = StateValue(UsedSpace())
    
    var progress: Double {
        steps.count.toDouble()
    }
    
    var total: CGFloat {
        commands.count.toDouble()
    }
    
    var freeUpSpace: Double {
        commands.reduce(0) { partial, command in
            partial + size(of: command)
        }.toDouble()
    }
    
    var status: CleanerStore.Status {
        if isCleaning {
            .isCleaning
        } else if !errors.isEmpty {
            .error
        } else if isCompleted {
            .isCompleted
        } else {
            .idle
        }
    }
    
    // MARK: - Private Variables
    
    private let commandExecutor: CommandExecutor
    private let preferences: Preferences
    private let analytics: Analytics
    
    private var isCleaning = false
    private var isCompleted = false
    private var steps = [CleanerStep]()
    private var calculateFreeUpSpaceTask: Task<Void, Error>?
    
    private var commands: [Command] {
        [
            preferences.removeArchives,
            preferences.removeCaches,
            preferences.removeDerivedData,
            preferences.removeOldSimulators,
            preferences.clearDeviceSupport,
            preferences.clearSimulatorData,
            preferences.resetXcodePreferences
        ]
        .filter { $0.value }
        .compactMap { $0.toCommand() }
    }
    
    private var errors: [Error] {
        steps.compactMap { $0.error }
    }
    
    // MARK: - Initializers
    
    init(
        commandExecutor: CommandExecutor,
        preferences: Preferences,
        analytics: Analytics
    ) {
        self.commandExecutor = commandExecutor
        self.preferences = preferences
        self.analytics = analytics
        
        calculateFreeUpSpace()
    }
    
    // MARK: - Public Methods
    
    func clear() {
        isCompleted = false
        isCleaning = true
        
        calculateFreeUpSpaceTask?.cancel()
        
        Task { @MainActor in
            await withTaskGroup(of: CleanerStep.self) { group in
                commands.forEach { command in
                    group.addTask(priority: .background) { [weak self] in
                        do {
                            try await self?.commandExecutor.run(command)
                            self?.calculateFreeUpSpace()
                            return .init(command)
                        } catch {
                            return .init(command, error: error)
                        }
                    }
                }
                
                while let step = await group.next() {
                    try? await Task.sleep(nanoseconds: 0.5.second)
                    steps.append(step)
                }
                
                analytics.log(.cleaner(commands))
                calculateFreeUpSpace()
                
                try? await Task.sleep(nanoseconds: 1.second)
                
                steps = steps.filter { $0.hasError }
                isCleaning = false
                isCompleted = true
                
                try? await Task.sleep(nanoseconds: 2.second)
                
                isCompleted = false
            }
        }
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Private Methods
    
    private func calculateFreeUpSpace() {
        usedSpace.isLoading = true
        
        calculateFreeUpSpaceTask = Task {
            let isCancelled = calculateFreeUpSpaceTask?.isCancelled ?? false
            
            do {
                let result: UsedSpace = try await commandExecutor.run(.calculateFreeUpSpace)
                
                if !isCancelled {
                    usedSpace.value = result
                }
            } catch {
                print(error)
            }
            
            usedSpace.isLoading = false
            
            if !isCancelled {
                try? await Task.sleep(nanoseconds: 3.second)
                calculateFreeUpSpace()
            }
        }
    }
    
}

extension CleanerStore {
    
    enum Status: Equatable {
        case idle
        case isCompleted
        case isCleaning
        case error
    }
    
    private func size(of command: Command) -> Int {
        switch command {
        case .removeArchives:
            usedSpace.value.archives
        case .removeCaches:
            usedSpace.value.cache
        case .removeDerivedData:
            usedSpace.value.derivedData
        case .clearDeviceSupport:
            usedSpace.value.deviceSupport
        case .clearSimulatorData:
            usedSpace.value.simulatorData
        default: 0
        }
    }
    
}

fileprivate struct CleanerStep: Equatable, Identifiable {
    
    // MARK: - Public Variables
    
    let command: Command
    let error: Error?
    
    var id: String {
        command.id
    }
    
    var hasError: Bool {
        error != nil
    }
    
    // MARK: - Initializers
    
    init(_ command: Command, error: Error? = nil) {
        self.command = command
        self.error = error
    }
    
    // MARK: - Public Methods
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
}

extension EnvironmentValues {
    
    @Entry var cleanerStore = CleanerStore(
        commandExecutor: Shell(),
        preferences: .init(),
        analytics: GoogleAnalytics()
    )
    
}
