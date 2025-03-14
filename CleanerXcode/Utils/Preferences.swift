//
//  Preferences.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class Preferences {
    
    // MARK: - Public Properties
    
    var canRemoveCache = true {
        didSet {
            update(
                command: .removeCache,
                status: canRemoveCache
            )
        }
    }
    
    var canRemoveDerivedData = true {
        didSet {
            update(
                command: .removeDerivedData,
                status: canRemoveDerivedData
            )
        }
    }
    
    var canRemoveDeviceSupport = true {
        didSet {
            update(
                command: .removeDeviceSupport,
                status: canRemoveDeviceSupport
            )
        }
    }
    
    var canRemoveOldSimulators = true {
        didSet {
            update(
                command: .removeOldSimulators,
                status: canRemoveOldSimulators
            )
        }
    }
    
    var canRemovePodCache = true {
        didSet {
            update(
                command: .removePodCache,
                status: canRemovePodCache
            )
        }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    
    private var commands = Set<ShellScriptCommander.Command>([]) {
        didSet {
            let value = commands.map { $0.rawValue }.joined(separator: ",")
            userDefaults.set(value, forKey: "commands")
        }
    }
    
    // MARK: - Initializers
    
    init() {
        commands = Set(userDefaults.string(forKey: "commands")?
            .split(separator: ",")
            .compactMap { .init(rawValue: .init($0)) } ?? [])
        
        canRemoveCache = commands.contains(.removeCache)
        canRemoveDerivedData = commands.contains(.removeDerivedData)
        canRemoveDeviceSupport = commands.contains(.removeDeviceSupport)
        canRemoveOldSimulators = commands.contains(.removeOldSimulators)
        canRemovePodCache = commands.contains(.removePodCache)
    }
    
    // MARK: - Private Methods
    
    private func update(command: ShellScriptCommander.Command, status: Bool) {
        if status {
            commands.insert(command)
        } else {
            commands.remove(command)
        }
    }
    
}

extension EnvironmentValues {
    
    @Entry var preferences = Preferences()
    
}
