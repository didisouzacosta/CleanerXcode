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
                progress: cleanerProgress,
                total: cleanerProgressTotal
            )
        } else if isCleanerCompleted {
            if cleanerSteps.contains(where: { $0.hasError }) {
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
    private let analytics: AnalyticsRepresentable
    
    private var timer: Timer?
    private var isCleanerCompleted = false
    private var cleanerSteps = [CleanerStep]()
    private var cleanerTask: Task<Void, Error>?
    
    private var cleanerProgress: Double {
        Double(cleanerSteps.count)
    }
    
    private var cleanerProgressTotal: CGFloat {
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
        analytics: AnalyticsRepresentable
    ) {
        self.commandExecutor = commandExecutor
        self.preferences = preferences
        self.analytics = analytics
        
        defer {
            startCheckFreeUpSpaceTimer()
            calculateFreeUpSpace()
        }
    }
    
    // MARK: - Public Methods
    
    func cleaner() {
        isCleaning = true
        isCleanerCompleted = false
        
        stopCheckFreeUpSpaceTimer()
        
        cleanerTask = Task { @MainActor in
            await withTaskGroup(of: CleanerStep.self) { group in
                commands.enumerated().forEach { index, command in
                    group.addTask(priority: .background) { [weak self] in
                        do {
                            try await self?.commandExecutor.run(command)
                            try Task.checkCancellation()
                            
                            self?.calculateFreeUpSpace()
                            
                            return .init(command.id)
                        } catch {
                            return .init(command.id, error: error)
                        }
                    }
                }
                
                while let step = await group.next() {
                    try? await Task.sleep(nanoseconds: 0.5.second)
                    cleanerSteps.append(step)
                }
                
                analytics.log(.cleaner(commands))
                calculateFreeUpSpace()
                
                try? await Task.sleep(nanoseconds: 1.second)
                
                isCleaning = false
                isCleanerCompleted = true
                cleanerSteps = cleanerSteps.filter { $0.hasError }
                
                try? await Task.sleep(nanoseconds: 2.second)
                
                isCleanerCompleted = false
                
                startCheckFreeUpSpaceTimer()
            }
        }
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func cancel() {
        cleanerTask?.cancel()
    }
    
    // MARK: - Private Methods
    
    private func startCheckFreeUpSpaceTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.calculateFreeUpSpace()
        }
    }
    
    private func stopCheckFreeUpSpaceTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func calculateFreeUpSpace() {
        usedSpace.isLoading = true
        
        Task(priority: .background) { @MainActor in
            do {
                let value = try await commandExecutor.run(.calculateFreeUpSpace)
                usedSpace.value = (try value?.data(using: .utf8)?.decoder()) ?? .init()
            } catch {
                print(error)
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
    
    let id: String
    let error: Error?
    
    var hasError: Bool {
        error != nil
    }
    
    // MARK: - Initializers
    
    init(_ id: String, error: Error? = nil) {
        self.id = id
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
        analytics: Analytics()
    )
    
}
