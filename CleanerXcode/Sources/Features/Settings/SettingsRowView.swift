//
//  SettingsRowView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import SwiftUI

/// One row of a Settings card (C40): the title, an optional subtitle and the control on the
/// right. The texts are only visual; the control carries the accessible label, and the subtitle
/// becomes its hint.
struct SettingsRowView<Accessory: View>: View {

    // MARK: - Public Properties

    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource?

    let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)

            Spacer(minLength: 8)

            accessory
                .accessibilityHint(subtitle.map { Text($0) } ?? Text(verbatim: ""))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: subtitle == nil ? 44 : 50)
    }

    // MARK: - Initializers

    init(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

}

/// The line between two consecutive rows of a Settings card (C40), inset like the rows' text;
/// never before the first row nor after the last one.
struct SettingsRowDivider: View {

    // MARK: - Public Properties

    var body: some View {
        Divider()
            .padding(.leading, 14)
    }

}

#if DEBUG
    #Preview("Rows") {
        @Previewable @State var isOn = true

        VStack(spacing: 0) {
            SettingsRowView(title: "Open at login") {
                Toggle("Open at login", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            SettingsRowDivider()

            SettingsRowView(
                title: "Show in the menu bar",
                subtitle: "Closing the window keeps CleanerXcode in the menu bar"
            ) {
                Toggle("Show in the menu bar", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .background(Palette.card, in: .rect(cornerRadius: 12))
        .padding()
        .frame(width: 628)
        .background(Palette.window)
    }
#endif
