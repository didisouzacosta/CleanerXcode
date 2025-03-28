//
//  Version+Extension.swift
//  CleanXCode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

extension Bundle: ApplicationInfo {
    
    var version: Double {
        let value = object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String? ?? "0"
        return Double(value) ?? 0
    }
    
    var build: Double {
        let value = object(forInfoDictionaryKey: "CFBundleVersion") as! String? ?? "0"
        return Double(value) ?? 0
    }
    
    var fullVersion: String {
        return "\(version).\(build)"
    }
    
}
