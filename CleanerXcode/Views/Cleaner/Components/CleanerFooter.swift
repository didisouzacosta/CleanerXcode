import SwiftUI

struct CleanerFooter: View {

    // MARK: - Private Properties

    private let versionTitle: String
    private let updateTitle: String?
    private let isPreferencesEnabled: Bool
    private let openPreferences: () -> Void
    private let openUpdate: () -> Void
    private let quit: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            Divider()

            GlassEffectContainer(spacing: 8) {
                HStack {
                    Button(action: openPreferences) {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(.glass)
                    .disabled(!isPreferencesEnabled)
                    .accessibilityLabel("Preferences")

                    HStack(spacing: 6) {
                        Text(versionTitle)
                            .foregroundStyle(.secondary)

                        if let updateTitle {
                            Button(updateTitle, action: openUpdate)
                                .buttonStyle(.glass)
                                .tint(.green)
                        }
                    }
                    .font(.footnote)

                    Spacer()

                    Button(action: quit) {
                        Label("Quit", systemImage: "power")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.glass)
                    .keyboardShortcut("q")
                }
            }
        }
    }

    // MARK: - Initializer

    init(
        versionTitle: String,
        updateTitle: String?,
        isPreferencesEnabled: Bool,
        openPreferences: @escaping () -> Void,
        openUpdate: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.versionTitle = versionTitle
        self.updateTitle = updateTitle
        self.isPreferencesEnabled = isPreferencesEnabled
        self.openPreferences = openPreferences
        self.openUpdate = openUpdate
        self.quit = quit
    }

}

#Preview {
    CleanerFooter(
        versionTitle: "Version 1.0.0",
        updateTitle: "Update",
        isPreferencesEnabled: true,
        openPreferences: {},
        openUpdate: {},
        quit: {}
    )
    .frame(width: 320)
    .padding()
}
