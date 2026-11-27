//
//  Bundle+Extension.swift
//  CleanXCode
//
//  Created by Adriano Costa on 13/03/25.
//

import Foundation

extension Bundle {

    // MARK: - Version

    var version: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var build: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

}
