//
//  SimulatorRowView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// A simulator: checkbox, device symbol, name, runtime, state, last use, duplicate badge and size.
struct SimulatorRowView: View {

    // MARK: - Public Properties

    let device: SimulatorDevice
    let viewModel: SimulatorsViewModel
    let isLocked: Bool

    var body: some View {
        Toggle(isOn: isSelected) {
            HStack(spacing: 10) {
                Image(systemName: SimulatorPresentation.systemImage(forDeviceType: device.deviceTypeIdentifier))
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: device.name)
                        .lineLimit(1)

                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if viewModel.duplicateUDIDs.contains(device.udid) {
                    Text("Duplicate")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: .capsule)
                }

                Text(valueText)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(isLocked || viewModel.phase.isDeleting)
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
        .accessibilityValue(Text(valueText))
    }

    // MARK: - Private Properties

    private var isSelected: Binding<Bool> {
        Binding {
            viewModel.selectedUDIDs.contains(device.udid)
        } set: { _ in
            viewModel.toggle(device.udid)
        }
    }

    private var isBeingDeleted: Bool {
        if case let .deleting(ids) = viewModel.phase {
            ids.contains(device.udid)
        } else {
            false
        }
    }

    private var valueText: LocalizedStringResource {
        isBeingDeleted ? "Deleting…" : "\(device.sizeBytes.formatted(.byteCount(style: .file)))"
    }

    /// "iOS 27.2 · off · last used 2 days ago".
    private var details: LocalizedStringResource {
        let runtime = SimulatorPresentation.runtimeName(device.runtimeIdentifier)
        let state = String(localized: device.state.title)
        let lastUse = if device.state == .booted {
            String(localized: "in use now")
        } else if let date = device.lastUsedAt {
            String(localized: "last used \(date.formatted(.relative(presentation: .numeric)))")
        } else {
            String(localized: "never used")
        }

        return "\(runtime) · \(state) · \(lastUse)"
    }

}

private extension SimulatorDevice.State {

    var title: LocalizedStringResource {
        switch self {
        case .booted: "on"
        case .shutdown: "off"
        case let .other(value): "\(value)"
        }
    }

}
