//
//  CategoryPageView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// A cleanup section's page (Figma page 08): its categories in one card. The rows behave as before.
struct CategoryPageView: View {

    // MARK: - Public Properties

    let group: CleanerSection.Group
    let viewModel: CleanerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(group.categories) { category in
                CategoryRowView(category: category, viewModel: viewModel)
            }
        }
        .background(Palette.card, in: .rect(cornerRadius: 12))
    }

}

#if DEBUG
    #Preview("Xcode") {
        CleanerWindowPreview(.ready, destination: .xcode)
    }

    #Preview("User data with Xcode open") {
        CleanerWindowPreview(.xcodeOpen, destination: .userData)
    }
#endif
