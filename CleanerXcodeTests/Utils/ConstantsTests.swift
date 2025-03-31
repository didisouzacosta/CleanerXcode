//
//  ConstantsTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct ConstantsTests {

    @Test func ensureSocialURLs() async throws {
        #expect(Constants.githubURL.absoluteString == "https://github.com/didisouzacosta/CleanerXcode")
        #expect(Constants.xURL.absoluteString == "https://x.com/didisouzacosta")
        #expect(Constants.linkedinURL.absoluteString == "https://www.linkedin.com/in/adrianosouzacosta")
    }

}
