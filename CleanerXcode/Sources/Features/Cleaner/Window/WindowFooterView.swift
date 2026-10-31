//
//  WindowFooterView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The version and, when there is a newer one, the button that opens its download.
struct WindowFooterView: View {

    // MARK: - Public Properties

    let updates: UpdateStore
    let versionText: String

    var body: some View {
        HStack {
            Text("Version \(versionText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if updates.hasUpdate.value, let version = updates.version {
                Link(destination: version.downloadURL) {
                    Text("Update to \(version.version)")
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
