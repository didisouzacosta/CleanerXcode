//
//  String+Formatter.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 17/03/25.
//

import SwiftUI

extension Double {
    
    func byteFormatter() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        
        return formatter.string(fromByteCount: Int64(self))
    }
    
}
