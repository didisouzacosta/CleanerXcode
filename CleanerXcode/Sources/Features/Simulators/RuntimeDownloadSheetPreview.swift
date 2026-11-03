//
//  RuntimeDownloadSheetPreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

#if DEBUG
    import SwiftUI

    /// The "Download runtimes" sheet on its own, over the page's in-memory lists (iOS 27.2 and 27.1
    /// installed), with the given platforms selected.
    struct RuntimeDownloadSheetPreview: View {

        // MARK: - States

        @State private var viewModel = SimulatorsSectionPreview.makeViewModel(for: .loaded)

        // MARK: - Public Properties

        var body: some View {
            ZStack {
                Color.clear

                if viewModel.downloadChoice != nil {
                    RuntimeDownloadSheet(viewModel: viewModel, isLocked: isLocked)
                }
            }
            .frame(width: 460, height: 436)
            .background(Palette.window)
            .task {
                await prepare()
            }
        }

        // MARK: - Private Properties

        private let selection: [RuntimePlatform]
        private let isLocked: Bool

        // MARK: - Initializers

        init(_ selection: [RuntimePlatform], isLocked: Bool = false) {
            self.selection = selection
            self.isLocked = isLocked
        }

        // MARK: - Private Methods

        private func prepare() async {
            await viewModel.load()
            viewModel.requestRuntimeDownload()

            for platform in selection {
                viewModel.toggleRuntimePlatform(platform)
            }
        }

    }
#endif
