//
//  VersionUpdateRowStyle.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import SwiftUI

/// The text size of `VersionUpdateRow`: small in the sidebar footer, a step larger on About.
enum VersionUpdateRowStyle {

    // MARK: - Cases

    case footer
    case about

    // MARK: - Public Properties

    var font: Font {
        switch self {
        case .footer: .caption
        case .about: .subheadline
        }
    }

}
