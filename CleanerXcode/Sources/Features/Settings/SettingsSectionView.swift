//
//  SettingsSectionView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import SwiftUI

/// A section of the Settings pages in the detail column (C40): the header outside the card, the
/// white card with its rows and an optional caption under it.
struct SettingsSectionView<Content: View>: View {

    // MARK: - Public Properties

    let title: LocalizedStringResource
    let footer: LocalizedStringResource?

    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: .rect(cornerRadius: 12))

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Initializers

    init(
        _ title: LocalizedStringResource,
        footer: LocalizedStringResource? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

}

#if DEBUG
    #Preview("Section") {
        SettingsSectionView(
            "Temporary folder",
            footer: "Items changed more recently are kept. Close AI apps and terminals before cleaning."
        ) {
            SettingsRowView(title: "Minimum age of the items") {
                Text(verbatim: "3 days")
            }
        }
        .padding()
        .frame(width: 628)
        .background(Palette.window)
    }
#endif
