//
//  RuntimeDownloadPlatformRow.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import SwiftUI

/// One platform: checkbox, symbol, name and what is installed, centered on one vertical axis (Figma
/// 47:1911), and the menu of versions at the right (C35, Figma 92:7540). A checkbox with a label
/// aligns to the label's first line, so the native checkbox has its label hidden and sits in a
/// centered row; the name and what is installed are a plain button that toggles it, so the row stays
/// clickable. VoiceOver reads the checkbox (the platform name is its label, what is installed its
/// hint, and its on/off value stays its own) and the menu ("iOS version").
struct RuntimeDownloadPlatformRow: View {

    // MARK: - Public Properties

    let row: RuntimeDownloadSheetContent.Row

    @Binding var isSelected: Bool
    @Binding var selectedOptionID: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Toggle(isOn: $isSelected) {
                Text(verbatim: row.platform.rawValue)
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityHint(Text(verbatim: row.installedDetail))

            Button(action: toggle) {
                HStack(alignment: .center, spacing: 10) {
                    // A fixed frame for every symbol: the iPhone glyph is taller than the TV one.
                    Image(systemName: row.systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.platform.rawValue)
                            .font(.body.weight(.semibold))

                        Text(verbatim: row.installedDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityHidden(true)

            Picker(selection: $selectedOptionID) {
                ForEach(row.options) { option in
                    Text(verbatim: option.label)
                        .tag(option.id)
                }
            } label: {
                Text(verbatim: menuLabel)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(Text(verbatim: menuLabel))
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 12)
    }

    // MARK: - Private Properties

    private var menuLabel: String {
        RuntimeDownloadSheetContent.versionMenuLabel(for: row.platform)
    }

    // MARK: - Private Methods

    private func toggle() {
        isSelected.toggle()
    }

}

#if DEBUG
    #Preview("Rows") {
        RuntimeDownloadSheetPreview([.watchOS], versions: [.iOS: "26.5"])
    }
#endif
