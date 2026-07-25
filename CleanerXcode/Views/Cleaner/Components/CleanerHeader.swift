import SwiftUI

struct CleanerHeader: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "hammer.fill")
                .font(.title3)
                .foregroundStyle(.tint)

            Text("Cleaner Xcode")
                .font(.title2.weight(.semibold))

            Text("Reclaim space used by Xcode")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

}

#Preview {
    CleanerHeader()
}
