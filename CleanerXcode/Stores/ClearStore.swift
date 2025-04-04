//
//  ClearStore.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class ClearStore {
    
    // MARK: - Public Variables
    
    private(set) var usedSpace = StateValue(UsedSpace())
    private(set) var isCleaning = false
    
    var cleanerStatus: Status {
        if isCleaning {
            .cleaning(
                progress: progress,
                total: total
            )
        } else if isCompleted {
            if steps.contains(where: { $0.hasError }) {
                .error
            } else {
                .completed
            }
        } else {
            .idle
        }
    }
    
    var freeUpSpace: Double {
        commands.reduce(0) { partial, command in
            partial + size(of: command)
        }.toDouble()
    }
    
    // MARK: - Private Variables
    
    private let commandExecutor: CommandExecutor
    private let preferences: Preferences
    private let analytics: Analytics
    
    private var isCompleted = false
    private var steps = [CleanerStep]()
    private var calculateFreeUpSpaceTask: Task<Void, Error>?
    
    private var progress: Double {
        Double(steps.count)
    }
    
    private var total: CGFloat {
        CGFloat(commands.count)
    }
    
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
    
    // MARK: - Initializers
    
    init(
        commandExecutor: CommandExecutor = Shell(),
        preferences: Preferences,
        analytics: Analytics
    ) {
        self.commandExecutor = commandExecutor
        self.preferences = preferences
        self.analytics = analytics
        
        calculateFreeUpSpace()
    }
    
    // MARK: - Public Methods
    
    func cleaner() {
        isCleaning = true
        isCompleted = false
        
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
                
                isCleaning = false
                isCompleted = true
                steps = steps.filter { $0.hasError }
                
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
            
            if !isCancelled {
                try? await Task.sleep(nanoseconds: 3.second)
                calculateFreeUpSpace()
            }
        }
    }
    
}

extension ClearStore {
    
    enum Status: Equatable {
        case idle
        case completed
        case cleaning(progress: Double, total: Double)
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
    
    @Entry var clearStore = ClearStore(
        commandExecutor: Shell(),
        preferences: .init(),
        analytics: GoogleAnalytics()
    )
    
}
