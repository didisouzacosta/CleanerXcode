//
//  AboutSettingsView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import AppKit
import SwiftUI

/// The About page in the detail column (C40, R17): the app, its version with the shared update
/// button, the donation, the social links and the dedication; logs `donate` and `social`.
struct AboutSettingsView: View {

    // MARK: - Environments

    @Environment(\.openURL) private var openURL

    // MARK: - Public Properties

    let viewModel: SettingsViewModel
    let updates: UpdateViewModel
    let versionText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AboutHeaderView(updates: updates, versionText: versionText)

            SupportCard(onSupport: support)

            SettingsSectionView("Links") {
                AboutLinkRow(title: "GitHub", subtitle: "Source code, issues and suggestions") {
                    open(Constants.githubURL, social: .github)
                }

                SettingsRowDivider()

                AboutLinkRow(title: "X", subtitle: nil) {
                    open(Constants.xURL, social: .xPlatform)
                }

                SettingsRowDivider()

                AboutLinkRow(title: "LinkedIn", subtitle: nil) {
                    open(Constants.linkedinURL, social: .linkedin)
                }
            }

            SettingsSectionView("Dedication") {
                Text(
                    """
                    This simple app was made for anyone who loves developing for Apple technologies.

                    I'd like to dedicate this app to my son Orlando and my wife Gisele.
                    """
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Private Methods

    private func support() {
        openURL(Constants.donateURL)
        viewModel.logDonation()
    }

    private func open(_ url: URL, social: AnalyticsEvent.Social) {
        openURL(url)
        viewModel.logSocial(social)
    }

}

/// The app icon, its name and the version row shared with the sidebar footer.
private struct AboutHeaderView: View {

    // MARK: - Public Properties

    let updates: UpdateViewModel
    let versionText: String

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)

            Text(verbatim: "CleanerXcode")
                .font(.title2.weight(.bold))

            VersionUpdateRow(updates: updates, versionText: versionText, style: .about)
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
    }

}

/// A link with its optional subtitle and a chevron, as a native-looking plain row.
private struct AboutLinkRow: View {

    // MARK: - Public Properties

    let title: String
    let subtitle: LocalizedStringResource?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: title)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: subtitle == nil ? 36 : 50)
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
                Text("Support this project")
                    .font(.callout.weight(.semibold))

                Text("Any amount helps keep CleanerXcode going, and all of it goes to shelters and hospitals.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onSupport) {
                Label("Support", systemImage: "heart.fill")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.support)
        }
        .padding(16)
        .background(Palette.support.opacity(0.12), in: .rect(cornerRadius: 16))
    }

}

#if DEBUG
    #Preview("About") {
        CleanerWindowPreview(.ready, destination: .about)
    }

    #Preview("Dark · About") {
        CleanerWindowPreview(.ready, destination: .about)
            .preferredColorScheme(.dark)
    }

    #Preview("About · up to date") {
        CleanerWindowPreview(.ready, destination: .about, hasUpdate: false)
    }
#endif
