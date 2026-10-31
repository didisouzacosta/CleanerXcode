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
        HStack {
            Button {
                openURL(Constants.donateURL)
                onSupport()
            } label: {
                Label("Support the project", systemImage: "heart.fill")
            }
            .buttonStyle(.glass)
            .tint(.pink)
            .controlSize(.small)

            Spacer()

            Text("Version \(versionText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let update = updates.availableUpdate {
                Button {
                    openURL(update.downloadURL)
                    updates.logUpdateOpened()
                } label: {
                    Text("Update to \(update.version)")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

}
