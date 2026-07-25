import Observation

@MainActor
protocol AppRouting: AnyObject {

    var path: AppRouter.Path { get }

    func showCleaner()
    func showPreferences()

}

@MainActor
@Observable
final class AppRouter: AppRouting {

    // MARK: - Public Properties

    private(set) var path: Path = .cleaner

    // MARK: - Public Methods

    func showCleaner() {
        path = .cleaner
    }

    func showPreferences() {
        path = .preferences
    }

}

extension AppRouter {

    enum Path: Hashable {
        case cleaner
        case preferences
    }

}
