//
//  Constants.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Foundation

struct Constants {

    // MARK: - Public Properties

    static let githubURL = staticURL("https://github.com/didisouzacosta/CleanerXcode")
    static let xURL = staticURL("https://x.com/didisouzacosta")
    static let linkedinURL = staticURL("https://www.linkedin.com/in/adrianosouzacosta")
    static let donateURL = staticURL("https://buy.stripe.com/00gcN772R2ns3wA9AA")
    /// Apple's public catalog of downloadable simulator runtimes, the one Xcode reads (C35, R1).
    nonisolated static let runtimeCatalogURL = staticURL(
        "https://devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex"
    )

    // MARK: - Public Methods

    /// Builds a URL from a literal known at compile time; an invalid literal is a programming error.
    nonisolated static func staticURL(_ string: StaticString) -> URL {
        guard let url = URL(string: "\(string)") else {
            preconditionFailure("Invalid static URL: \(string)")
        }

        return url
    }

}
