//
//  SimulatorsConfirmationSheet.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The danger confirmation before deleting simulators or a runtime (R8, R9). Deleting a runtime
/// also deletes the simulators that use it, and it has to be downloaded again.
struct SimulatorsConfirmationSheet: View {

    // MARK: - Private Properties

    private static let listedLimit = 6

    // MARK: - Public Properties

    let confirmation: SimulatorsViewModel.Confirmation
    let viewModel: SimulatorsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text(title)
            }
            .font(.title2.weight(.semibold))

            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case let .devices(devices) = confirmation {
                deviceList(devices)
            }

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    viewModel.cancelConfirmation()
                }
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    Task { await viewModel.confirm() }
                } label: {
                    Text(confirmTitle)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    // MARK: - Private Properties

    private var title: LocalizedStringResource {
        switch confirmation {
        case let .devices(devices): "Delete \(devices.count) simulators?"
        case let .runtime(runtime, _): "Delete \(SimulatorPresentation.runtimeName(runtime.runtimeIdentifier))?"
        }
    }

    private var message: LocalizedStringResource {
        switch confirmation {
        case .devices:
            "Booted simulators are shut down first. Their apps and data are deleted for good."

        case let .runtime(_, dependentCount) where dependentCount == 0:
            "The runtime has to be downloaded again to be used."

        case let .runtime(_, dependentCount):
            """
            The \(dependentCount) simulators that use it are deleted too, and the runtime has to be \
            downloaded again to be used.
            """
        }
    }

    private var confirmTitle: LocalizedStringResource {
        if case .runtime = confirmation {
            "Delete runtime"
        } else {
            "Delete"
        }
    }

    // MARK: - Private Methods

    private func deviceList(_ devices: [SimulatorDevice]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(devices.prefix(Self.listedLimit)) { device in
                HStack {
                    Text(verbatim: device.name)

                    Spacer()

                    Text(verbatim: SimulatorPresentation.runtimeName(device.runtimeIdentifier))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }

            if devices.count > Self.listedLimit {
                Text("and \(devices.count - Self.listedLimit) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }

}
