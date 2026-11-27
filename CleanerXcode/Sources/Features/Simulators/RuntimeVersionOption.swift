//
//  RuntimeVersionOption.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation

/// One version in a platform's menu of the "Download runtimes" sheet (C35, R3): the selected
/// Xcode's version (`version == nil`, the download of the C30) or an earlier one.
struct RuntimeVersionOption: Identifiable, Hashable {

    // MARK: - Public Properties

    /// `nil` downloads the version that matches the selected Xcode, without `-buildVersion`.
    let version: RuntimeBuildVersion?
    /// Already localized: "27.2 (Xcode)", "Xcode version" or "26.5".
    let title: String
    /// From the catalog, when it lists the version.
    let sizeBytes: Int64?

    var id: String {
        version?.rawValue ?? "xcode"
    }

    /// "26.5 · 8,52 GB", or only the title without a size.
    var label: String {
        guard let sizeBytes else { return title }

        return "\(title) · \(sizeBytes.formatted(.byteCount(style: .file)))"
    }

}
