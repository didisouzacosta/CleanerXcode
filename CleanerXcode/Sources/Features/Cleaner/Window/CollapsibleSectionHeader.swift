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
    let summary: LocalizedStringResource

    var body: some View {
        Button {
            withAnimation(.snappy) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.headline)

                Spacer()

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isCollapsed ? Text("Collapsed") : Text("Expanded"))
        .accessibilityHint("Shows or hides the items of this section")
    }

}
