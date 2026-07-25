import SwiftUI

struct PreferencesView: View {

    // MARK: - Private Properties

    private let viewModel: PreferencesViewModel

    // MARK: - Body

    var body: some View {

        // MARK: - Bindables

        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 12) {
            Button(action: viewModel.showCleaner) {
                Label("Home", systemImage: "chevron.backward")
            }
            .buttonStyle(.glass)
            .padding(.horizontal)
            .padding(.top)

            Form {
                Section("Cache") {
                    PreferenceToggleRow(
                        "Remove Archives",
                        detail: viewModel.archivesDetail,
                        isOn: $viewModel.removeArchives
                    )

                    PreferenceToggleRow(
                        "Remove Caches",
                        detail: viewModel.cachesDetail,
                        isOn: $viewModel.removeCaches
                    )

                    PreferenceToggleRow(
                        "Remove Derived Data",
                        detail: viewModel.derivedDataDetail,
                        isOn: $viewModel.removeDerivedData
                    )
                }

                Section("Simulators & Xcode") {
                    PreferenceToggleRow(
                        "Clear Device Support",
                        detail: viewModel.deviceSupportDetail,
                        isOn: $viewModel.clearDeviceSupport
                    )

                    PreferenceToggleRow(
                        "Clear Simulator Data",
                        detail: viewModel.simulatorDataDetail,
                        isOn: $viewModel.clearSimulatorData
                    )

                    PreferenceToggleRow(
                        "Remove Old Simulators",
                        isOn: $viewModel.removeOldSimulators
                    )

                    PreferenceToggleRow(
                        "Reset Xcode Preferences",
                        isOn: $viewModel.resetXcodePreferences
                    )
                }

                Section("Preferences") {
                    PreferenceToggleRow(
                        "Display Free Space in Menu Bar",
                        isOn: $viewModel.displayFreeUpSpaceInMenuBar
                    )

                    PreferenceToggleRow(
                        "Launch at Login",
                        isOn: $viewModel.launchAtLogin
                    )
                }

                Section("About") {
                    Text("Made for developers who want to keep Xcode fast and disk usage under control.")
                        .foregroundStyle(.secondary)

                    Button("Donate", action: viewModel.donate)
                        .buttonStyle(.glassProminent)
                        .tint(.orange)
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Initializer

    init(_ viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
    }

}

#Preview {
    PreferencesView(PreviewFactory.container().preferencesViewModel)
        .frame(width: 340, height: 540)
}
