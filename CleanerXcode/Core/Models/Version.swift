//
//  Version.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 28/03/25.
//

import Foundation

struct Version: Decodable {
    
    // MARK: - Public Variables
    
    let version: Int
    let build: Int
    let downloadURL: URL
    
    // MARK: - Initializers
    
    init(
        version: Int,
        build: Int,
        downloadURL: URL
    ) {
        self.version = version
        self.build = build
        self.downloadURL = downloadURL
    }
    
    enum CodingKeys: CodingKey {
        case version
        case build
        case downloadURL
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let versionString = try container.decode(String.self, forKey: .version)
        
        self.version = Int(versionString.split(separator: ".").joined()) ?? 0
        self.build = try container.decode(Int.self, forKey: .build)
        self.downloadURL = try container.decode(URL.self, forKey: .downloadURL)
    }
    
}
