//
//  ConstantsTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Foundation
import Testing
@testable import CleanerXcode

struct ConstantsTests {

    // MARK: - Public Methods

    @Test
    func ensureSocialURLs() throws {
        #expect(Constants.githubURL.absoluteString == "https://github.com/didisouzacosta/CleanerXcode")
        #expect(Constants.xURL.absoluteString == "https://x.com/didisouzacosta")
        #expect(Constants.linkedinURL.absoluteString == "https://www.linkedin.com/in/adrianosouzacosta")
    }

    @Test
    func ensureDonateURL() {
        #expect(Constants.donateURL.absoluteString == "https://buy.stripe.com/4gM6oI9L8eNX6A99gWaEE01")
    }

}
