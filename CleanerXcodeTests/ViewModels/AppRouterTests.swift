import Testing

@testable import CleanerXcode

@MainActor
struct AppRouterTests {

    @Test
    func routesBetweenCleanerAndPreferences() {
        let router = AppRouter()

        #expect(router.path == .cleaner)

        router.showPreferences()

        #expect(router.path == .preferences)

        router.showCleaner()

        #expect(router.path == .cleaner)
    }

}
