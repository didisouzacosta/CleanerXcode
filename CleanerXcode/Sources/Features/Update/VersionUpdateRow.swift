//
//  VersionUpdateRow.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import SwiftUI

/// "Version x (y)" and, only when there is a newer version, a small round button that opens its
/// download (C40). The same row sits in the sidebar footer and on the About page.
struct VersionUpdateRow: View {

    // MARK: - Environments

    @Environment(\.openURL) private var openURL

    // MARK: - Public Properties

    let updates: UpdateViewModel
    let versionText: String
    let style: VersionUpdateRowStyle

    var body: some View {
        HStack(spacing: 8) {
            Text("Version \(versionText)")
                .font(style.font)
                .foregroundStyle(.secondary)

            if let update = updates.availableUpdate {
                Button(action: openUpdate) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(.blue, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Update to \(update.version)"))
                .help(Text("Update to \(update.version)"))
                .subtleTransition()
            }
        }
        .subtleAnimation(value: updates.availableUpdate != nil)
    }

    // MARK: - Private Methods

    private func openUpdate() {
        guard let update = updates.availableUpdate else { return }

        openURL(update.downloadURL)
        updates.logUpdateOpened()
    }

}

#if DEBUG
    #Preview("Footer · up to date") {
        VersionUpdateRow(updates: UpdatePreview.makeViewModel(), versionText: "1.0.0 (115)", style: .footer)
            .padding()
    }

    #Preview("Footer · update available") {
        @Previewable @State var updates = UpdatePreview.makeViewModel(hasUpdate: true)

        VersionUpdateRow(updates: updates, versionText: "1.0.0 (115)", style: .footer)
            .padding()
            .task { await updates.check() }
    }

    #Preview("About · update available") {
        @Previewable @State var updates = UpdatePreview.makeViewModel(hasUpdate: true)

        VersionUpdateRow(updates: updates, versionText: "1.0.0 (115)", style: .about)
            .padding()
            .task { await updates.check() }
    }
#endif
