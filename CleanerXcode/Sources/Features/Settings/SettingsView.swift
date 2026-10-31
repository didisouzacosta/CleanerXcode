//
//  SettingsView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The `Settings` scene (Cmd+, or the toolbar button): General and About (Figma page 04).
struct SettingsView: View {

    // MARK: - Public Properties

    let viewModel: SettingsViewModel
    let updates: UpdateViewModel
    let versionText: String

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView(viewModel: viewModel)
            }

            Tab("About", systemImage: "info.circle") {
                AboutSettingsView(viewModel: viewModel, updates: updates, versionText: versionText)
            }
        }
        .frame(width: 520)
    }

}

#if DEBUG
    #Preview("General") {
        GeneralSettingsView(viewModel: SettingsPreview.makeViewModel())
            .frame(width: 520)
    }

    #Preview("General · login item waiting for approval") {
        GeneralSettingsView(viewModel: SettingsPreview.makeViewModel(loginItemStatus: .requiresApproval))
            .frame(width: 520)
    }

    #Preview("About") {
        AboutSettingsView(
            viewModel: SettingsPreview.makeViewModel(),
            updates: UpdatePreview.makeViewModel(),
            versionText: "1.0.0 (115)"
        )
        .frame(width: 520)
    }

    #Preview("About · update available") {
        let updates = UpdatePreview.makeViewModel(hasUpdate: true)

        AboutSettingsView(viewModel: SettingsPreview.makeViewModel(), updates: updates, versionText: "1.0.0 (115)")
            .frame(width: 520)
            .task {
                await updates.check()
            }
    }

    #Preview("General · Dark") {
        GeneralSettingsView(viewModel: SettingsPreview.makeViewModel())
            .frame(width: 520)
            .preferredColorScheme(.dark)
    }
#endif
