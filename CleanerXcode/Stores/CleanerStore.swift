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
    private(set) var status: CleanerStore.Status = .idle
    
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
    
    // MARK: - Private Variables
    
    private let commandExecutor: CommandExecutor
    private let preferences: Preferences
    private let analytics: Analytics
    
    private var steps = [CleanerStep]()
    private var timer: Timer?
    private var calculateFreeUpSpaceTask: Task<Void, Error>?
    private var cleanerTask: Task<Void, Error>?
    
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
        status = .isCleaning
        steps = []
        
        stopTimer()
        
        cleanerTask?.cancel()
        cleanerTask = Task { @MainActor in
            await withTaskGroup(of: CleanerStep.self) { group in
                guard !Task.isCancelled else { return }
                
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
                status = .isCompleted
                
                try? await Task.sleep(nanoseconds: 2.second)
                
                status = .idle
                
                await Task.yield()
            }
        }
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Private Methos
    
    private func startTimer() {
        timer = Timer(
            fire: .now.addingTimeInterval(6),
            interval: 0,
            repeats: false
        ) { [weak self] _ in
            self?.calculateFreeUpSpace()
        }
        
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func stopTimer() {
        calculateFreeUpSpaceTask?.cancel()
        timer?.invalidate()
        timer = nil
    }
    
    private func calculateFreeUpSpace() {
        usedSpace.isLoading = true
        
        stopTimer()
        
        calculateFreeUpSpaceTask?.cancel()
        calculateFreeUpSpaceTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            usedSpace.value = (try? await commandExecutor.runDecoder(.calculateFreeUpSpace)) ?? .init()
            await Task.yield()
            startTimer()
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
