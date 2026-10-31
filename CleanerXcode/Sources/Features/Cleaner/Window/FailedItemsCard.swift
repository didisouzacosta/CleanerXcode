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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items that failed")
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
        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
    }

}
