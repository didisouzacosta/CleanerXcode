import Foundation

enum CleanupAction: String, CaseIterable, Identifiable, Sendable {

    // MARK: - Public Properties

    case removeArchives = "remove-archives"
    case removeCaches = "remove-caches"
    case removeDerivedData = "remove-derived-data"
    case clearDeviceSupport = "clear-device-support"
    case clearSimulatorData = "clear-simulator-data"
    case removeOldSimulators = "remove-old-simulators"
    case resetXcodePreferences = "reset-xcode-preferences"

    var id: String {
        rawValue
    }
}
