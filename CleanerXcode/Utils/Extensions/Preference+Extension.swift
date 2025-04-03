//
//  Preference+Extension.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

extension StoragedValue {
    
    func toCommand() -> Command? {
        Command.commands.first { $0.script == key }
    }
    
}
