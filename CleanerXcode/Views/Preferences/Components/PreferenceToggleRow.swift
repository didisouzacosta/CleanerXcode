import SwiftUI

struct PreferenceToggleRow: View {

    // MARK: - Bindings

    @Binding private var isOn: Bool

    // MARK: - Private Properties

    private let detail: String?
    private let title: LocalizedStringKey

    // MARK: - Body

    var body: some View {
        HStack {
            Text(title)

            Spacer()

            if let detail {
                Text(detail)
                    .contentTransition(.numericText())
                    .foregroundStyle(.secondary)
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }

    // MARK: - Initializer

    init(
        _ title: LocalizedStringKey,
        detail: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

}

#Preview {

    // MARK: - States

    @Previewable @State var isOn = true

    Form {
        PreferenceToggleRow(
            "Remove Derived Data",
            detail: "2.4 GB",
            isOn: $isOn
        )
    }
    .formStyle(.grouped)
    .frame(width: 320)
}
