//
//  SidebarFooterView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The bottom of the sidebar (Figma page 08): "Support the project", the version and, when there
/// is a newer one, the button that opens its download.
struct SidebarFooterView: View {

    // MARK: - Environments

    @Environment(\.openURL) private var openURL

    // MARK: - Public Properties

    let updates: UpdateViewModel
    let versionText: String
    let onSupport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: support) {
                Label("Support the project", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.support)
                    .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 12))
                    .background(Palette.support.opacity(0.1), in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)

            Text("Version \(versionText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let update = updates.availableUpdate {
                Button(action: openUpdate) {
                    Text("Update to \(update.version)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .subtleTransition()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        .subtleAnimation(value: updates.availableUpdate != nil)
    }

    // MARK: - Private Methods

    private func support() {
        openURL(Constants.donateURL)
        onSupport()
    }

    private func openUpdate() {
        guard let update = updates.availableUpdate else { return }

        openURL(update.downloadURL)
        updates.logUpdateOpened()
    }

}

#if DEBUG
    #Preview("Up to date") {
        SidebarFooterView(updates: UpdatePreview.makeViewModel(), versionText: "1.0.0 (115)") {}
            .frame(width: 244)
    }

    #Preview("Update available") {
        @Previewable @State var updates = UpdatePreview.makeViewModel(hasUpdate: true)

        SidebarFooterView(updates: updates, versionText: "1.0.0 (115)") {}
            .frame(width: 244)
            .task { await updates.check() }
    }
#endif
