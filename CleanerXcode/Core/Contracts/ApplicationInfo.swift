//
//  ApplicationInfo.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 28/03/25.
//

import Foundation

protocol ApplicationInfo {
    
    var version: String { get }
    var build: String { get }
    var fullVersion: String { get }
    
    func loadLatestVersionFromRemote() async throws -> Version
    
}

extension ApplicationInfo {
    
    func loadLatestVersionFromRemote() async throws -> Version {
        guard let url = Bundle.main.versionFileURL else {
            throw ""
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        return try data.decoder()
    }
    
}
