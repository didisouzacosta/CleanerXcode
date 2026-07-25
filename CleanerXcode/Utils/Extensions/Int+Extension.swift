//
//  Int+Extension.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 19/03/25.
//

import Foundation

extension Int {
    
    var second: UInt64 {
        UInt64(self) * UInt64(1_000_000_000)
    }
    
    func toDouble() -> Double {
        Double(self)
    }
    
    func byteFormatted() -> String {
        Double(self).byteFormatter()
    }
    
}

extension Int64 {

    // MARK: - Public Methods

    func toDouble() -> Double {
        Double(self)
    }

    func byteFormatted() -> String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Double {
    
    var second: UInt64 {
        UInt64(self) * UInt64(1_000_000_000)
    }
    
}
