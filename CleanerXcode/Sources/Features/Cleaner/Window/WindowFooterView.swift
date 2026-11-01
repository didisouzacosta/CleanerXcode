//
//  WindowFooterView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// "Support the project", the version and, when there is a newer one, the button that opens
/// its download.
struct WindowFooterView: View {

    // MARK: - Environments

    @Environment(\.openURL) private var openURL

    // MARK: - Public Properties

    let updates: UpdateViewModel
    let versionText: String
    let onSupport: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                openURL(Constants.donateURL)
                onSupport()
            } label: {
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
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)

            if let update = updates.availableUpdate {
                Button {
                    openURL(update.downloadURL)
                    updates.logUpdateOpened()
                } label: {
                    Text("Update to \(update.version)")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .subtleTransition()
            }
        }
        .frame(minHeight: 28)
        .subtleAnimation(value: updates.availableUpdate != nil)
        .padding(EdgeInsets(top: 8, leading: 20, bottom: 14, trailing: 20))
        .background(Palette.window)
    }

}

#if DEBUG
    #Preview("Up to date") {
        WindowFooterView(updates: UpdatePreview.makeViewModel(), versionText: "1.0.0 (115)") {}
            .frame(width: 560)
    }

    #Preview("Update available") {
        @Previewable @State var updates = UpdatePreview.makeViewModel(hasUpdate: true)

        WindowFooterView(updates: updates, versionText: "1.0.0 (115)") {}
            .frame(width: 560)
            .task { await updates.check() }
    }
#endif
