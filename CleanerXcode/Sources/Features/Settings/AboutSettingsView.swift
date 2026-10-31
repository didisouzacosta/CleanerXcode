//
//  AboutSettingsView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import AppKit
import SwiftUI

/// Version, update, donation, social links and the dedication (R17); logs `donate` and `social`.
struct AboutSettingsView: View {

    // MARK: - Environments

    @Environment(\.openURL) private var openURL

    // MARK: - Public Properties

    let viewModel: SettingsViewModel
    let updates: UpdateStore
    let versionText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                SupportCard {
                    openURL(Constants.donateURL)
                    viewModel.logDonation()
                }

                section("Links") {
                    link(
                        "GitHub",
                        subtitle: "Source code, issues and suggestions",
                        url: Constants.githubURL,
                        social: .github
                    )
                    link("X", subtitle: nil, url: Constants.xURL, social: .xPlatform)
                    link("LinkedIn", subtitle: nil, url: Constants.linkedinURL, social: .linkedin)
                }

                section("Dedication") {
                    Text(
                        """
                        This simple app was made for anyone who loves developing for Apple technologies.

                        I'd like to dedicate this app to my son Orlando and my wife Gisele.
                        """
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
            }
            .padding(20)
        }
        .frame(height: 560)
    }

    // MARK: - Private Properties

    private var header: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text(verbatim: "CleanerXcode")
                .font(.title2.weight(.bold))

            Text("Version \(versionText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if updates.hasUpdate.value, let version = updates.version {
                Link(destination: version.downloadURL) {
                    Text("Update to \(version.version)")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Private Methods

    private func section(_ title: LocalizedStringResource, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                rows()
            }
            .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
        }
    }

    private func link(
        _ title: String,
        subtitle: LocalizedStringResource?,
        url: URL,
        social: AnalyticsEvent.Social
    ) -> some View {
        Button {
            openURL(url)
            viewModel.logSocial(social)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 36)
            .padding(.horizontal, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

}

/// "Support the project": any amount helps, and all of it goes to shelters and hospitals.
private struct SupportCard: View {

    // MARK: - Public Properties

    let onSupport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(.pink)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Support the project")
                    .font(.callout.weight(.semibold))

                Text("Any amount helps keep CleanerXcode going, and all of it goes to shelters and hospitals.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onSupport) {
                Label("Support", systemImage: "heart.fill")
            }
            .buttonStyle(.glassProminent)
            .tint(.pink)
        }
        .padding(16)
        .background(.pink.opacity(0.12), in: .rect(cornerRadius: 16))
    }

}
