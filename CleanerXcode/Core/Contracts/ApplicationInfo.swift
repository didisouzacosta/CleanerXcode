//
//  ApplicationInfo.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 28/03/25.
//

import Foundation

protocol ApplicationInfo {
    
    var version: Double { get }
    var build: Double { get }
    var fullVersion: String { get }
    
}
