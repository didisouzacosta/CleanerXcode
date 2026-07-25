import SwiftUI

struct SocialActionsView: View {

    // MARK: - Private Properties

    private let action: (AnalyticsEvent.Social) -> Void

    // MARK: - Body

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                socialButton(.github, image: "github.fill")
                socialButton(.x, image: "x")
                socialButton(.linkedin, image: "linkedin")
            }
        }
    }

    // MARK: - Initializer

    init(action: @escaping (AnalyticsEvent.Social) -> Void) {
        self.action = action
    }

    // MARK: - Private Methods

    private func socialButton(
        _ social: AnalyticsEvent.Social,
        image: String
    ) -> some View {
        Button {
            action(social)
        } label: {
            Image(image)
                .frame(width: 16, height: 16)
                .padding(4)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(social.accessibilityTitle)
    }

}

private extension AnalyticsEvent.Social {

    var accessibilityTitle: String {
        switch self {
        case .github:
            "Open GitHub"
        case .x:
            "Open X"
        case .linkedin:
            "Open LinkedIn"
        }
    }

}

#Preview {
    SocialActionsView(action: { _ in })
        .padding()
}
