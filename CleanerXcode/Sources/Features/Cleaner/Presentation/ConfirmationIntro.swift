//
//  ConfirmationIntro.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The first sentence of the confirmation names the kinds of risk it lists (Figma, sheet 7:119);
/// a plan with only safe items asks because an app is open.
enum ConfirmationIntro: Equatable {

    // MARK: - Cases

    case attentionAndDangerous
    case attention
    case dangerous
    case appsOpen

    // MARK: - Public Properties

    var text: LocalizedStringResource {
        switch self {
        case .attentionAndDangerous:
            "You selected items that need attention and dangerous items. Check what happens to each one before continuing."
        case .attention:
            "You selected items that need attention. Check what happens to each one before continuing."
        case .dangerous:
            "You selected dangerous items. Check what happens to each one before continuing."
        case .appsOpen:
            "Some apps are open. Check what happens to each item before continuing."
        }
    }

    // MARK: - Initializers

    init(risks: [RiskLevel]) {
        switch (risks.contains(.attention), risks.contains(.dangerous)) {
        case (true, true): self = .attentionAndDangerous
        case (true, false): self = .attention
        case (false, true): self = .dangerous
        case (false, false): self = .appsOpen
        }
    }

}
