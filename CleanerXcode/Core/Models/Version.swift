//
//  Version.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 28/03/25.
//

import Foundation

struct Version: Decodable {
    
    // MARK: - Public Variables
    
    let version: String
    let build: String
    let downloadURL: URL
    
    // MARK: - Initializers
    
    init(
        version: String,
        build: String,
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
    
}
