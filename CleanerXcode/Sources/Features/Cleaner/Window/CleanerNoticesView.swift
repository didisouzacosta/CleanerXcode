//
//  CleanerNoticesView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The fixed notices (plan section 2.4): Xcode open, simulators open, the Xcode tools missing,
/// a permission denied, and the selected items that go to the Trash.
struct CleanerNoticesView: View {

    // MARK: - Public Properties

    let viewModel: CleanerViewModel

    var body: some View {
        VStack(spacing: 8) {
            if case .permissionDenied = viewModel.phase {
                NoticeView(
                    systemImage: "lock.fill",
                    tint: .red,
                    title: "Full Disk Access needed",
                    message: """
                    macOS blocked access to some folders. Open System Settings › Privacy & Security › \
                    Full Disk Access, turn on CleanerXcode and try again.
                    """
                )
            }

            if viewModel.restrictions.isXcodeRunning {
                NoticeView(
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange,
                    title: "Xcode is open",
                    message: "Close Xcode to clean its user data and preferences. DerivedData may have items in use."
                )
            }

            if viewModel.restrictions.areSimulatorsActive {
                NoticeView(
                    systemImage: "ipad.and.iphone",
                    tint: .orange,
                    title: "Simulators are open",
                    message: "They will be shut down before the Simulators items are cleaned."
                )
            }

            if viewModel.areSimulatorToolsUnavailable {
                NoticeView(
                    systemImage: "wrench.and.screwdriver.fill",
                    tint: .orange,
                    title: "Xcode tools unavailable",
                    message: """
                    Install Xcode or select it in Xcode › Settings › Locations. \
                    The other categories keep working.
                    """
                )
            }

            if !viewModel.trashBoundCategoryIDs.isEmpty {
                NoticeView(
                    systemImage: "trash",
                    tint: .secondary,
                    title: "Some items go to the Trash",
                    message: "They only free space after you empty the Trash."
                )
            }
        }
    }

}

private struct NoticeView: View {

    // MARK: - Public Properties

    let systemImage: String
    let tint: Color
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

}
