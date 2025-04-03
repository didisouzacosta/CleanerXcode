//
//  Int+Extension.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 19/03/25.
//

extension Int {
    
    var second: UInt64 {
        UInt64(self) * UInt64(1_000_000_000)
    }
    
    func toDouble() -> Double {
        Double(self)
    }
    
}

extension Double {
    
    var second: UInt64 {
        UInt64(self) * UInt64(1_000_000_000)
    }
    
}
