//
//  SectionCardView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// An overview card that opens its page (Figma page 08): the section symbol on a tinted square,
/// the title, the summary and a chevron.
struct SectionCardView: View {

    // MARK: - Public Properties

    let title: LocalizedStringResource
    /// Already localized: summaries join several phrases.
    let subtitle: String
    let systemImage: String
    let tint: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.15), in: .rect(cornerRadius: 8))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(verbatim: subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(Palette.card, in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .help(subtitle)
        .accessibilityHint(Text("Opens this section"))
    }

}

#if DEBUG
    #Preview("Cards") {
        VStack(spacing: 12) {
            SectionCardView(
                title: "Xcode",
                subtitle: "2 of 5 selected · 31.3 GB",
                systemImage: "square.stack.3d.up",
                tint: .blue
            ) {}

            SectionCardView(
                title: "Simulators and runtimes",
                subtitle: "14 simulators · 3 duplicates (7.2 GB) · 2 runtimes (15.1 GB)",
                systemImage: "iphone",
                tint: .gray
            ) {}
        }
        .padding()
        .frame(width: 628)
        .background(Palette.window)
    }
#endif
