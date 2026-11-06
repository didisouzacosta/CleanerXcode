//
//  GeneralSettingsView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The General page in the detail column (C40): open at login, the menu bar item, the minimum age
/// of the temporary items and the usage statistics switch (R14, R15, D7), in cards without a
/// `Form`, as in the approved layout.
struct GeneralSettingsView: View {

    // MARK: - Private Properties

    private static let loginItemsURL: URL = {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            preconditionFailure("Invalid System Settings URL.")
        }

        return url
    }()

    // MARK: - Environments

    @Environment(\.openURL) private var openURL

    // MARK: - Public Properties

    let viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionView("Startup") {
                SettingsRowView(title: "Open at login") {
                    SettingsSwitch("Open at login", isOn: binding(viewModel.launchAtLogin, viewModel.setLaunchAtLogin))
                }

                if viewModel.loginItemNeedsApproval {
                    LoginItemApprovalRow(onOpen: openLoginItems)
                        .subtleTransition()
                }

                if let failure = viewModel.loginItemFailure {
                    Text("Could not change it: \(failure.summary)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
                        .subtleTransition()
                }
            }

            SettingsSectionView("Menu bar") {
                SettingsRowView(
                    title: "Show in the menu bar",
                    subtitle: "Closing the window keeps CleanerXcode in the menu bar"
                ) {
                    SettingsSwitch(
                        "Show in the menu bar",
                        isOn: binding(viewModel.showsMenuBarExtra, viewModel.setShowsMenuBarExtra)
                    )
                }

                SettingsRowView(title: "Show the size that can be freed") {
                    SettingsSwitch(
                        "Show the size that can be freed",
                        isOn: binding(viewModel.showsSizeInMenuBar, viewModel.setShowsSizeInMenuBar)
                    )
                    .disabled(!viewModel.showsMenuBarExtra)
                }
            }

            SettingsSectionView(
                "Temporary folder",
                footer: "Items changed more recently are kept. Close AI apps and terminals before cleaning."
            ) {
                SettingsRowView(title: "Minimum age of the items") {
                    Picker(
                        "Minimum age of the items",
                        selection: binding(viewModel.minimumTemporaryAgeInDays, viewModel.setMinimumTemporaryAgeInDays)
                    ) {
                        ForEach(SettingsViewModel.minimumAgeOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsSectionView(
                "Privacy",
                footer: "No personal data, file names or paths. App errors are reported without personal data."
            ) {
                SettingsRowView(title: "Send anonymous usage statistics") {
                    SettingsSwitch(
                        "Send anonymous usage statistics",
                        isOn: binding(viewModel.sendsUsageStatistics, viewModel.setSendsUsageStatistics)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .subtleAnimation(value: viewModel.loginItemNeedsApproval)
        .subtleAnimation(value: viewModel.loginItemFailure)
        .onAppear {
            viewModel.readLoginItem()
        }
    }

    // MARK: - Private Methods

    private func binding<Value>(_ value: Value, _ set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding {
            value
        } set: { newValue in
            set(newValue)
        }
    }

    private func openLoginItems() {
        openURL(Self.loginItemsURL)
    }

}

/// A native switch whose label only reaches VoiceOver: the row shows the title.
private struct SettingsSwitch: View {

    // MARK: - Public Properties

    let title: LocalizedStringResource

    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
        }
        .toggleStyle(.switch)
        .labelsHidden()
    }

    // MARK: - Initializers

    init(_ title: LocalizedStringResource, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

}

/// The login item waits for the user's approval in System Settings.
private struct LoginItemApprovalRow: View {

    // MARK: - Public Properties

    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Allow CleanerXcode in System Settings › General › Login Items.")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Open Login Items", action: onOpen)
        }
        .padding(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
    }

}

#if DEBUG
    #Preview("General") {
        CleanerWindowPreview(.ready, destination: .general)
    }

    #Preview("Dark · General") {
        CleanerWindowPreview(.ready, destination: .general)
            .preferredColorScheme(.dark)
    }

    #Preview("General · login item waiting for approval") {
        GeneralSettingsView(viewModel: SettingsPreview.makeViewModel(loginItemStatus: .requiresApproval))
            .padding()
            .frame(width: 628)
            .background(Palette.window)
    }
#endif
