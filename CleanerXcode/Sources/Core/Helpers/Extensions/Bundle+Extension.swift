//
//  Bundle+Extension.swift
//  CleanXCode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

extension Bundle {

    // MARK: - Info Dictionary Values

    var versionFileURL: URL? {
        guard let stringURL = infoDictionary?["VERSION_FILE_URL"] as? String else {
            return nil
        }

        return .init(string: stringURL)
    }

}

extension Bundle: ApplicationInfo {

    // MARK: - ApplicationInfo

    var version: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var build: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var fullVersion: String {
        "\(version).\(build)"
    }

}
