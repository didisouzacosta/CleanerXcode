import SwiftUI

struct CleanerView: View {

    // MARK: - Private Properties

    private let viewModel: CleanerViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            CleanerHeader()

            Spacer(minLength: 22)

            VStack(spacing: 18) {
                CleanerActionButton(
                    viewModel.buttonState,
                    action: viewModel.clean
                )

                SocialActionsView(action: viewModel.openSocial)
            }

            Spacer(minLength: 22)

            CleanerFooter(
                versionTitle: viewModel.versionTitle,
                updateTitle: viewModel.updateTitle,
                isPreferencesEnabled: viewModel.isPreferencesEnabled,
                openPreferences: viewModel.openPreferences,
                openUpdate: viewModel.openUpdate,
                quit: viewModel.quit
            )
        }
        .padding([.top, .leading, .trailing])
        .padding(.bottom, 12)
    }

    // MARK: - Initializer

    init(_ viewModel: CleanerViewModel) {
        self.viewModel = viewModel
    }

}

#Preview {
    CleanerView(PreviewFactory.container().cleanerViewModel)
        .frame(width: 340, height: 330)
}
