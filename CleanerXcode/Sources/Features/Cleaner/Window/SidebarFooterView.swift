//
//  SidebarFooterView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The bottom of the sidebar (Figma page 08, centred since C40): "Support the project" with a
/// filled heart, then the version with the small update button when there is a newer one.
struct SidebarFooterView: View {

    // MARK: - Environments

    @Environment(\.openURL) private var openURL

    // MARK: - Public Properties

    let updates: UpdateViewModel
    let versionText: String
    let onSupport: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: support) {
                // The heart is filled and shares the text's colour (C40), whatever the sidebar
                // applies to its own symbols.
                Label {
                    Text("Support the project")
                } icon: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Palette.support)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.support)
                .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 12))
                .background(Palette.support.opacity(0.1), in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)

            VersionUpdateRow(updates: updates, versionText: versionText, style: .footer)
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
    }

    // MARK: - Private Methods

    private func support() {
        openURL(Constants.donateURL)
        onSupport()
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
