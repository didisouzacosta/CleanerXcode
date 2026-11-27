//
//  CenteredCheckboxToggleStyle.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The checkbox centred on a row of the list, as in the approved layout (the system style aligns
/// it with the first line). The whole row, padding included, is one button, and VoiceOver reads
/// one checkbox with its state.
struct CenteredCheckboxToggleStyle: ToggleStyle {

    // MARK: - Public Properties

    var minHeight: CGFloat = 52
    var insets = EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 14)

    // MARK: - Public Methods

    func makeBody(configuration: Configuration) -> some View {
        CenteredCheckboxRow(configuration: configuration, minHeight: minHeight, insets: insets)
    }

}

private struct CenteredCheckboxRow: View {

    // MARK: - Environments

    @Environment(\.isEnabled) private var isEnabled

    // MARK: - Public Properties

    let configuration: ToggleStyleConfiguration
    let minHeight: CGFloat
    let insets: EdgeInsets

    var body: some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                // Only drawn: the row's button toggles, so a click on the box never counts twice.
                // Disabled, it keeps its colour at half opacity, as in the approved layout.
                Toggle(isOn: .constant(configuration.isOn)) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .allowsHitTesting(false)
                .environment(\.isEnabled, true)
                .opacity(isEnabled ? 1 : 0.5)
                .accessibilityHidden(true)

                configuration.label
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .padding(insets)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
        }
    }

}
