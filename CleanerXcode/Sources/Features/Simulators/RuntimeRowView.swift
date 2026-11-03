//
//  RuntimeRowView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// A runtime: name, build, how many simulators depend on it, last use, size and Remove. Runtimes
/// bundled with Xcode cannot be removed (R9), nor any runtime while one is downloaded (C30).
struct RuntimeRowView: View {

    // MARK: - Public Properties

    let runtime: SimulatorRuntime
    let viewModel: SimulatorsViewModel
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: SimulatorPresentation.runtimeName(runtime.runtimeIdentifier))
                    .lineLimit(1)

                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(valueText)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button("Remove", role: .destructive) {
                viewModel.requestDeleteRuntime(runtime)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
            .disabled(isLocked || viewModel.phase.isDeleting || isDownloading || !runtime.isDeletable)
            .help(removeHelp)
            .accessibilityLabel(Text("Remove \(SimulatorPresentation.runtimeName(runtime.runtimeIdentifier))"))
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Private Properties

    private var isDownloading: Bool {
        viewModel.runtimeDownload.isDownloading
    }

    private var removeHelp: Text {
        if !runtime.isDeletable {
            Text("Bundled with Xcode")
        } else if isDownloading {
            Text("Wait for the runtime download to finish")
        } else {
            Text("Remove this runtime")
        }
    }

    private var isBeingDeleted: Bool {
        if case let .deleting(ids) = viewModel.phase {
            ids.contains(runtime.identifier)
        } else {
            false
        }
    }

    private var valueText: LocalizedStringResource {
        isBeingDeleted ? "Deleting…" : "\(runtime.sizeBytes.formatted(.byteCount(style: .file)))"
    }

    /// "24A94425 · 3 simulators depend on it · last used 61 days ago".
    private var details: LocalizedStringResource {
        let dependents = String(localized: "\(viewModel.dependentCount(of: runtime)) simulators depend on it")
        let usage = if let state = SimulatorPresentation.runtimeStateText(runtime.state) {
            String(localized: state)
        } else if !runtime.isDeletable {
            String(localized: "bundled with Xcode")
        } else if let lastUsedAt = runtime.lastUsedAt {
            String(localized: "last used \(lastUsedAt.formatted(.relative(presentation: .numeric)))")
        } else {
            String(localized: "never used")
        }

        return "\(runtime.build) · \(dependents) · \(usage)"
    }

}
