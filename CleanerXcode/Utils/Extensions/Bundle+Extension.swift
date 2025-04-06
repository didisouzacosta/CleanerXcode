//
//  Version+Extension.swift
//  CleanXCode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

extension Bundle {
    
    var versionFileURL: URL? {
        guard let stringURL = infoDictionary?["VERSION_FILE_URL"] as? String else {
            return nil
        }
        
        return .init(string: stringURL)
    }
    
    var mixpanelToken: String {
        infoDictionary?["MIXPANEL_TOKEN"] as? String ?? ""
    }
    
}

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
