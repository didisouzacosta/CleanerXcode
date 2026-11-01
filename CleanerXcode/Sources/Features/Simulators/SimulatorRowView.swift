//
//  SimulatorRowView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// A simulator: checkbox, device symbol, name, runtime, state, last use, duplicate badge and size.
struct SimulatorRowView: View {

    // MARK: - Environments

    @Environment(\.colorSchemeContrast) private var contrast

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
                    .accessibilityLabel(Text(verbatim: spokenType ?? ""))
                    // Read only for a renamed simulator, whose name no longer tells its type.
                    .accessibilityHidden(spokenType == nil)

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
                        .badgeBackground(.orange, in: .capsule, contrast: contrast)
                }

                Text(valueText)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
        .toggleStyle(CenteredCheckboxToggleStyle(
            minHeight: 44,
            insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        ))
        .disabled(isLocked || viewModel.phase.isDeleting)
    }

    // MARK: - Private Properties

    private var spokenType: String? {
        SimulatorPresentation.spokenType(name: device.name, deviceType: device.deviceTypeIdentifier)
    }

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
        let state = String(localized: SimulatorPresentation.deviceStateText(
            device.state,
            isAvailable: device.isAvailable
        ))
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
