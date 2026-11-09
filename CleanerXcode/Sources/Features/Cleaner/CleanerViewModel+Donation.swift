//
//  CleanerViewModel+Donation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// The donation suggestion (C31) on the view model the window and the panel already observe; the
/// state and its rules live in `DonationPrompt`.
extension CleanerViewModel {

    // MARK: - Public Properties

    /// The fifth, tenth… success suggests a donation instead of OK.
    var suggestsDonation: Bool {
        donation.suggestsDonation
    }

    var isShowingSupportSheet: Bool {
        donation.isShowingSupportSheet
    }

    // MARK: - Public Methods

    /// "Support the project": opens the sheet, with no event.
    func supportProject() {
        donation.supportProject()
    }

    /// "Donate any amount" in the sheet: logs `donate` and closes it.
    func donateFromSupportSheet() {
        donation.donateFromSupportSheet()
    }

    /// "Not now", Esc or any other way of closing the sheet.
    func dismissSupportSheet() {
        donation.dismissSupportSheet()
    }

}
