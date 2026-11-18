//
//  RuntimeDownloadSheetPreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

#if DEBUG
    import SwiftUI

    /// The "Download runtimes" sheet on its own, over the page's in-memory lists (iOS 27.2 and 27.1
    /// installed), with the given platforms selected, the given earlier versions chosen (C35), and the
    /// versions loaded, loading or unavailable.
    struct RuntimeDownloadSheetPreview: View {

        // MARK: - States

        @State private var viewModel: SimulatorsViewModel

        // MARK: - Public Properties

        var body: some View {
            ZStack {
                Color.clear

                if viewModel.downloadChoice != nil {
                    RuntimeDownloadSheet(viewModel: viewModel, isLocked: isLocked)
                }
            }
            .frame(width: 520)
            .fixedSize(horizontal: false, vertical: true)
            .background(Palette.window)
            .task {
                await prepare()
            }
        }

        // MARK: - Private Properties

        private let selection: [RuntimePlatform]
        private let versions: [RuntimePlatform: String]
        private let isLocked: Bool

        // MARK: - Initializers

        init(
            _ selection: [RuntimePlatform],
            versions: [RuntimePlatform: String] = [:],
            source: PreviewRuntimeVersionSource.Behavior = .loaded,
            isLocked: Bool = false
        ) {
            self.selection = selection
            self.versions = versions
            self.isLocked = isLocked
            _viewModel = State(initialValue: SimulatorsSectionPreview.makeViewModel(
                for: .loaded,
                versionSource: PreviewRuntimeVersionSource(source)
            ))
        }

        // MARK: - Private Methods

        private func prepare() async {
            await viewModel.load()
            viewModel.requestRuntimeDownload()

            for platform in selection {
                viewModel.toggleRuntimePlatform(platform)
            }

            for platform in RuntimePlatform.allCases {
                if let version = versions[platform].flatMap(RuntimeBuildVersion.init) {
                    viewModel.selectRuntimeVersion(version, for: platform)
                }
            }
        }

    }
#endif
