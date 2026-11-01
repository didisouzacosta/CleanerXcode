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
    /// Simulators or a runtime are being deleted: shutting everything down now could break it.
    var isDeletingSimulators = false

    var body: some View {
        VStack(spacing: 8) {
            if case let .permissionDenied(report) = viewModel.phase {
                NoticeView(
                    systemImage: "lock.fill",
                    tint: .red,
                    title: "Full Disk Access needed",
                    message: permissionMessage(report)
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
                    message: "They will be shut down before the Simulators items are cleaned.",
                    action: NoticeView.Action(
                        title: "Shut down now",
                        isEnabled: viewModel.phase.allowsMeasurement && !isDeletingSimulators
                    ) {
                        Task { await viewModel.shutDownSimulators() }
                    }
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

extension CleanerNoticesView {

    // MARK: - Public Methods

    /// Whether any notice shows; without one the window leaves no empty gap (same conditions as
    /// `body`).
    static func hasNotices(_ viewModel: CleanerViewModel) -> Bool {
        if case .permissionDenied = viewModel.phase {
            return true
        }

        return viewModel.restrictions.isXcodeRunning
            || viewModel.restrictions.areSimulatorsActive
            || viewModel.areSimulatorToolsUnavailable
            || !viewModel.trashBoundCategoryIDs.isEmpty
    }

}

private extension CleanerNoticesView {

    // MARK: - Private Methods

    /// Names the folder when macOS blocked only one, as in the approved layout.
    func permissionMessage(_ report: CleanupReport) -> LocalizedStringResource {
        let blocked = report.permissionDeniedResults

        if blocked.count == 1 {
            return """
            macOS blocked \(blocked[0].displayPath). Open System Settings › Privacy & Security › \
            Full Disk Access, turn on CleanerXcode and try again.
            """
        }

        return """
        macOS blocked access to some folders. Open System Settings › Privacy & Security › \
        Full Disk Access, turn on CleanerXcode and try again.
        """
    }

}

private struct NoticeView: View {

    // MARK: - Environments

    @Environment(\.colorSchemeContrast) private var contrast

    // MARK: - Public Properties

    let systemImage: String
    let tint: Color
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var action: Action?

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

            if let action {
                Button(action.title, action: action.perform)
                    .controlSize(.small)
                    .disabled(!action.isEnabled)
            }
        }
        .padding(12)
        .badgeBackground(tint, in: .rect(cornerRadius: 12), contrast: contrast)
        .accessibilityElement(children: .contain)
        .subtleTransition()
    }

    // MARK: - Nested Types

    struct Action {
        let title: LocalizedStringResource
        let isEnabled: Bool
        let perform: () -> Void
    }

}

#if DEBUG
    #Preview("Xcode open") {
        @Previewable @State var viewModel = CleanerWindowPreview.makeViewModel(for: .xcodeOpen)

        // Always-present content, so the task runs before any notice exists.
        ZStack {
            Color.clear

            CleanerNoticesView(viewModel: viewModel)
                .padding()
        }
        .frame(width: 560, height: 160)
        .task { await viewModel.refresh() }
    }

    #Preview("Simulator open") {
        @Previewable @State var viewModel = CleanerWindowPreview.makeViewModel(for: .simulatorOpen)

        // Always-present content, so the task runs before any notice exists.
        ZStack {
            Color.clear

            CleanerNoticesView(viewModel: viewModel)
                .padding()
        }
        .frame(width: 560, height: 160)
        .task { await viewModel.refresh() }
    }

    #Preview("Simulator open · deleting simulators") {
        @Previewable @State var viewModel = CleanerWindowPreview.makeViewModel(for: .simulatorOpen)

        // Always-present content, so the task runs before any notice exists.
        ZStack {
            Color.clear

            CleanerNoticesView(viewModel: viewModel, isDeletingSimulators: true)
                .padding()
        }
        .frame(width: 560, height: 160)
        .task { await viewModel.refresh() }
    }

    #Preview("Xcode tools unavailable") {
        @Previewable @State var viewModel = CleanerWindowPreview.makeViewModel(for: .toolsUnavailable)

        // Always-present content, so the task runs before any notice exists.
        ZStack {
            Color.clear

            CleanerNoticesView(viewModel: viewModel)
                .padding()
        }
        .frame(width: 560, height: 160)
        .task { await viewModel.refresh() }
    }
#endif
