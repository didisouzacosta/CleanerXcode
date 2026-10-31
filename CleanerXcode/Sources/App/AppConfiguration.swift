//
//  AppConfiguration.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

nonisolated struct AppConfiguration: Equatable, Sendable {

    // MARK: - Public Properties

    let versionFileURL: URL?
    let himetricaAPIKey: String?
    let sentryDSN: String?
    let bundleIdentifier: String?
    let version: String?
    let build: String?

    // MARK: - Initializers

    init(
        versionFileURL: URL? = nil,
        himetricaAPIKey: String? = nil,
        sentryDSN: String? = nil,
        bundleIdentifier: String? = nil,
        version: String? = nil,
        build: String? = nil
    ) {
        self.versionFileURL = versionFileURL
        self.himetricaAPIKey = himetricaAPIKey
        self.sentryDSN = sentryDSN
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.build = build
    }

    /// Reads the values injected by `Config.xcconfig` (and the git-ignored `Secrets.xcconfig`)
    /// into `Info.plist`. Missing, blank or unexpanded values mean "not configured".
    init(infoDictionary: [String: Any]) {
        let versionFileURL = Self.configuredValue(for: "VERSION_FILE_URL", in: infoDictionary)

        self.init(
            versionFileURL: versionFileURL.flatMap(URL.init(string:)),
            himetricaAPIKey: Self.configuredValue(for: "HIMETRICA_API_KEY", in: infoDictionary),
            sentryDSN: Self.configuredValue(for: "SENTRY_DSN", in: infoDictionary).flatMap(Self.validDSN),
            bundleIdentifier: Self.configuredValue(for: "CFBundleIdentifier", in: infoDictionary),
            version: Self.configuredValue(for: "CFBundleShortVersionString", in: infoDictionary),
            build: Self.configuredValue(for: "CFBundleVersion", in: infoDictionary)
        )
    }

    // MARK: - Private Methods

    private static func configuredValue(for key: String, in infoDictionary: [String: Any]) -> String? {
        let value = (infoDictionary[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }

        return value
    }

    /// A DSN broken by the `//` comment rule of `.xcconfig` (for example `https:`) means "not configured".
    private static func validDSN(_ value: String) -> String? {
        guard
            let components = URLComponents(string: value),
            components.scheme == "https" || components.scheme == "http",
            let host = components.host,
            !host.isEmpty
        else { return nil }

        return value
    }

}
