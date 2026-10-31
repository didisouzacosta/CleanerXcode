//
//  GeneralSettingsView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// Open at login, the menu bar item, the minimum age of the temporary items and the usage
/// statistics switch (R14, R15, D7).
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
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: binding(viewModel.launchAtLogin, viewModel.setLaunchAtLogin))

                if viewModel.loginItemNeedsApproval {
                    LabeledContent {
                        Button("Open Login Items") {
                            openURL(Self.loginItemsURL)
                        }
                    } label: {
                        Text("Allow CleanerXcode in System Settings › General › Login Items.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let failure = viewModel.loginItemFailure {
                    Text("Could not change it: \(failure.summary)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Menu bar") {
                Toggle(isOn: binding(viewModel.showsMenuBarExtra, viewModel.setShowsMenuBarExtra)) {
                    Text("Show in the menu bar")
                    Text("Closing the window keeps CleanerXcode in the menu bar")
                }

                Toggle(
                    "Show the size that can be freed",
                    isOn: binding(viewModel.showsSizeInMenuBar, viewModel.setShowsSizeInMenuBar)
                )
                .disabled(!viewModel.showsMenuBarExtra)
            }

            Section {
                Picker(
                    "Minimum age of the items",
                    selection: binding(viewModel.minimumTemporaryAgeInDays, viewModel.setMinimumTemporaryAgeInDays)
                ) {
                    ForEach(SettingsViewModel.minimumAgeOptions, id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
            } header: {
                Text("Temporary folder")
            } footer: {
                Text("Items changed more recently are kept. Close AI apps and terminals before cleaning.")
            }

            Section {
                Toggle(
                    "Send usage statistics",
                    isOn: binding(viewModel.sendsUsageStatistics, viewModel.setSendsUsageStatistics)
                )
            } header: {
                Text("Privacy")
            } footer: {
                Text("""
                Statistics use a random identifier, never personal data, file names or paths. App errors are \
                reported without personal data.
                """)
            }
        }
        .formStyle(.grouped)
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

}
