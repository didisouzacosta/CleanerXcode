//
//  Version.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 28/03/25.
//

import Foundation

struct Version: Decodable {
    
    // MARK: - Public Variables
    
    let version: Double
    let build: Double
    let downloadURL: URL
    
    // MARK: - Initializers
    
    init(
        version: Double,
        build: Double,
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
        self.version = Double(try container.decode(String.self, forKey: .version)) ?? 0
        self.build = Double(try container.decode(String.self, forKey: .build)) ?? 0
        self.downloadURL = try container.decode(URL.self, forKey: .downloadURL)
    }
    
}
