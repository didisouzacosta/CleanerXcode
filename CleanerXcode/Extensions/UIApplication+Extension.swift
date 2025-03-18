//
//  Version+Extension.swift
//  CleanXCode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

extension NSApplication {
    
    static var release: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String? ?? "x.x"
    }
    
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String? ?? "x"
    }
    
    static var fullVersion: String {
        return "\(release).\(build)"
    }
    
}
