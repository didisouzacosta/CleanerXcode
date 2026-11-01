//
//  CollapsibleSectionHeader.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The chevron, title and summary that collapse or expand a section of the list.
struct CollapsibleSectionHeader: View {

    // MARK: - Bindings

    @Binding var isCollapsed: Bool

    // MARK: - Public Properties

    let title: LocalizedStringResource
    /// Already localized: some summaries join several phrases.
    let summary: String

    var body: some View {
        Button {
            withAnimation(.snappy) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.headline)

                Spacer()

                Text(verbatim: summary)
                    .font(.subheadline)
                    .contentTransition(.opacity)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isCollapsed ? Text("Collapsed") : Text("Expanded"))
        .accessibilityHint("Shows or hides the items of this section")
    }

}

#if DEBUG
    #Preview("Expanded and collapsed") {
        @Previewable @State var isCollapsed = false
        @Previewable @State var isOtherCollapsed = true

        VStack(spacing: 16) {
            CollapsibleSectionHeader(isCollapsed: $isCollapsed, title: "Xcode", summary: "31.3 GB selected")
            CollapsibleSectionHeader(
                isCollapsed: $isOtherCollapsed,
                title: "Temporary files",
                summary: "0 of 1 selected"
            )
        }
        .padding()
        .frame(width: 560)
    }
#endif
