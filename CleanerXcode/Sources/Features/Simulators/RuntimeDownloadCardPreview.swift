//
//  RuntimeDownloadCardPreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

#if DEBUG
    import SwiftUI

    /// The runtime download card on its own, in each state, at the width of the page's column.
    struct RuntimeDownloadCardPreview: View {

        // MARK: - Public Properties

        var body: some View {
            RuntimeDownloadCardView(
                presentation: RuntimeDownloadPresentation(state: state),
                isActionDisabled: isActionDisabled,
                disabledHelp: isActionDisabled ? "Available when the cleanup ends" : nil,
                onChoose: {},
                onRetry: {},
                onCancel: {}
            )
            .padding(20)
            .frame(width: 668)
            .background(Palette.window)
        }

        // MARK: - Private Properties

        private let state: RuntimeDownloadState
        private let isActionDisabled: Bool

        // MARK: - Initializers

        init(_ state: RuntimeDownloadState, isActionDisabled: Bool = false) {
            self.state = state
            self.isActionDisabled = isActionDisabled
        }

    }
#endif
