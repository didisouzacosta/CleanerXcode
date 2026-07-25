import SwiftUI

struct CleanerActionButton: View {

    // MARK: - Private Properties

    private let action: () -> Void
    private let state: CleanerButtonState

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ProgressView(
                    value: state.progress,
                    total: state.total
                )
                .progressViewStyle(.circular)
                .controlSize(.small)
                .opacity(state.showsProgress ? 1 : 0)
                .frame(width: 14, height: 14)

                Text(state.title)
                    .contentTransition(.numericText())
            }
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glassProminent)
        .tint(state.tint)
        .disabled(!state.isEnabled)
        .animation(.snappy, value: state)
        .accessibilityLabel(state.title)
    }

    // MARK: - Initializer

    init(
        _ state: CleanerButtonState,
        action: @escaping () -> Void
    ) {
        self.state = state
        self.action = action
    }

}

#Preview("Idle") {
    CleanerActionButton(
        CleanerButtonState(
            title: "Clear 3.4 GB",
            tint: .blue,
            progress: 0,
            total: 3,
            showsProgress: false,
            isEnabled: true
        ),
        action: {}
    )
    .padding()
}

#Preview("Cleaning") {
    CleanerActionButton(
        CleanerButtonState(
            title: "Cleaning",
            tint: .green,
            progress: 2,
            total: 4,
            showsProgress: true,
            isEnabled: false
        ),
        action: {}
    )
    .padding()
}

#Preview("Completed") {
    CleanerActionButton(
        CleanerButtonState(
            title: "🎉 Success, all clear!",
            tint: .green,
            progress: 4,
            total: 4,
            showsProgress: false,
            isEnabled: false
        ),
        action: {}
    )
    .padding()
}

#Preview("Error") {
    CleanerActionButton(
        CleanerButtonState(
            title: "Try again",
            tint: .red,
            progress: 2,
            total: 4,
            showsProgress: false,
            isEnabled: true
        ),
        action: {}
    )
    .padding()
}
