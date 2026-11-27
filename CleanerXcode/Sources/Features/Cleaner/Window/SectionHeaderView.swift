//
//  SectionHeaderView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// A group title with an optional caption on the right, such as "Sections" or "Runtimes".
struct SectionHeaderView: View {

    // MARK: - Public Properties

    let title: LocalizedStringResource

    /// Already localized: some captions join several phrases.
    var caption: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            Text(verbatim: caption ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .lineLimit(1)
        }
        .padding(.top, 4)
    }

}

#if DEBUG
    #Preview("With and without caption") {
        VStack(spacing: 16) {
            SectionHeaderView(title: "Sections", caption: "4 categories with selected items")
            SectionHeaderView(title: "Sections")
        }
        .padding()
        .frame(width: 628)
    }
#endif
