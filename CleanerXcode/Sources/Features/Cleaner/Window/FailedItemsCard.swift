//
//  FailedItemsCard.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The items of the last report that could not be removed, with the reason of each one.
struct FailedItemsCard: View {

    // MARK: - Public Properties

    let results: [CleanupItemResult]
    /// "No item was removed" when the whole run failed.
    var title: LocalizedStringResource = "Items that failed"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: result.displayPath)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if case let .failed(error) = result.outcome {
                            Text(error.summary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.card, in: .rect(cornerRadius: 12))
    }

}

#if DEBUG
    #Preview {
        FailedItemsCard(results: [
            CleanupItemResult(
                categoryID: .removeDerivedData,
                displayPath: "~/Library/Developer/Xcode/DerivedData/MyApp-fhq/Index.noindex",
                bytes: 0,
                outcome: .failed(.inUse)
            ),
            CleanupItemResult(
                categoryID: .removeDerivedData,
                displayPath: "~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex",
                bytes: 0,
                outcome: .failed(.permissionDenied)
            ),
        ])
        .padding()
        .frame(width: 560)
    }
#endif
