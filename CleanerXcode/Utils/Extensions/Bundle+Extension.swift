//
//  Version+Extension.swift
//  CleanXCode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

extension Bundle: ApplicationInfo {
    
    var version: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String? ?? "0"
    }
    
    var build: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as! String? ?? "0"
    }
    
    var fullVersion: String {
        return "\(version).\(build)"
    }
    
}
