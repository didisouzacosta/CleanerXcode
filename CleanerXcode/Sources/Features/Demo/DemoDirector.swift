//
//  DemoDirector.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    /// What the tour does to the window.
    protocol DemoDriving: AnyObject {
        func refresh() async
        func show(_ destination: SidebarDestination)
        func toggle(_ id: CleanupCategoryID)
        func requestClean() async
        func confirm() async
        func dismissReport()
    }

    /// Plays the steps in order; a cancelled wait ends the tour.
    struct DemoDirector {

        // MARK: - Public Properties

        let steps: [DemoStep]
        let sleep: (Duration) async throws -> Void

        // MARK: - Initializers

        init(steps: [DemoStep], sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
            self.steps = steps
            self.sleep = sleep
        }

        // MARK: - Public Methods

        func run(on driver: any DemoDriving) async {
            for step in steps {
                guard !Task.isCancelled else { return }

                switch step {
                case let .wait(duration):
                    do {
                        try await sleep(duration)
                    } catch {
                        return
                    }

                case .refresh:
                    await driver.refresh()

                case let .show(destination):
                    driver.show(destination)

                case let .toggle(id):
                    driver.toggle(id)

                case .requestClean:
                    await driver.requestClean()

                case .confirm:
                    await driver.confirm()

                case .dismissReport:
                    driver.dismissReport()
                }
            }
        }

    }
#endif
