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
    
    private(set) var usedSpace = StateValue<UsedSpace>(.init(), state: .isLoading)
    private(set) var isCleaning = false
    
    var cleanerStatus: Status {
        if isCleaning {
            .cleaning(
                progress: cleanerProgress,
                total: cleanerProgressTotal
            )
        } else if isCleanerCompleted {
            .completed
        } else {
            .idle
        }
    }
    
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
    private var isCleanerCompleted = false
    private var cleanerSteps = [CleanerStep]()
    
    private var cleanerProgress: Double {
        Double(cleanerSteps.count)
    }
    
    private var cleanerProgressTotal: CGFloat {
        CGFloat(enabledCommands.count)
    }
    
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
    
    @MainActor
    func cleaner() async throws {
        isCleaning = true
        isCleanerCompleted = false
        
        await withTaskGroup(of: CleanerStep.self) { group in
            enabledCommands.enumerated().forEach { index, command in
                group.addTask(priority: .background) { [weak self] in
                    do {
                        try await self?.shell.execute(command)
                        return .init(command.id, error: nil)
                    } catch {
                        return .init(command.id, error: error)
                    }
                }
            }
            
            while let step = await group.next() {
                try? await Task.sleep(nanoseconds: 1.second / 2)
                cleanerSteps.append(step)
            }
            
            calculateFreeUpSpace()
            analytics.log(.cleaner(enabledCommands))
            
            try? await Task.sleep(nanoseconds: 1.second)
            
            isCleaning = false
            isCleanerCompleted = true
            cleanerSteps = []
            
            try? await Task.sleep(nanoseconds: 2.second)
            
            isCleanerCompleted = false
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
        usedSpace.state = .isLoading
        
        Task(priority: .background) { @MainActor in
            let value = try? await shell.execute(.calculateFreeUpSpace)
            let usedSpace: UsedSpace = (try? value?.data(using: .utf8)?.decoder()) ?? .init()
            self.usedSpace.state = .success(usedSpace)
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
    
    private func size(of command: Shell.Command) -> Int {
        switch command {
        case .removeArchives: usedSpace.value.archives
        case .removeCaches: usedSpace.value.cache
        case .removeDerivedData: usedSpace.value.derivedData
        case .clearDeviceSupport: usedSpace.value.deviceSupport
        case .clearSimulatorData: usedSpace.value.simulatorData
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
    
    init(_ id: String, error: Error?) {
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
        .init(),
        analytics: Analytics()
    )
    
}
