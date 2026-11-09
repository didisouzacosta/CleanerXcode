//
//  DemoTourDriver.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    /// Drives the real window: the router picks the page, the view model measures and cleans.
    final class DemoTourDriver: DemoDriving {

        // MARK: - Private Properties

        private let viewModel: CleanerViewModel
        private let router: AppRouter

        // MARK: - Initializers

        init(viewModel: CleanerViewModel, router: AppRouter) {
            self.viewModel = viewModel
            self.router = router
        }

        // MARK: - Public Methods

        func refresh() async {
            await viewModel.refresh()
        }

        func show(_ destination: SidebarDestination) {
            router.show(destination)
        }

        func toggle(_ id: CleanupCategoryID) {
            viewModel.toggle(id)
        }

        func requestClean() async {
            await viewModel.requestClean()
        }

        func confirm() async {
            await viewModel.confirm()
        }

        func dismissReport() {
            viewModel.dismissReport()
        }

    }
#endif
