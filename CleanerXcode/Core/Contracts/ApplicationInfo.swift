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
    
}
