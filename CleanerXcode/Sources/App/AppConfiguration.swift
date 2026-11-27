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
    /// Sparkle's appcast (C42): https only.
    let sparkleFeedURL: URL?
    /// Sparkle's public EdDSA key: updates signed with another key are refused.
    let sparklePublicKey: String?
    let himetricaAPIKey: String?
    let sentryDSN: String?
    let bundleIdentifier: String?
    let version: String?
    let build: String?

    /// Sparkle needs both the feed and the key; without them the app keeps `version.json`.
    var isSparkleConfigured: Bool {
        sparkleFeedURL != nil && sparklePublicKey != nil
    }

    // MARK: - Initializers

    init(
        versionFileURL: URL? = nil,
        sparkleFeedURL: URL? = nil,
        sparklePublicKey: String? = nil,
        himetricaAPIKey: String? = nil,
        sentryDSN: String? = nil,
        bundleIdentifier: String? = nil,
        version: String? = nil,
        build: String? = nil
    ) {
        self.versionFileURL = versionFileURL
        self.sparkleFeedURL = sparkleFeedURL
        self.sparklePublicKey = sparklePublicKey
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
            sparkleFeedURL: Self.configuredValue(for: "SUFeedURL", in: infoDictionary).flatMap(Self.httpsURL),
            sparklePublicKey: Self.configuredValue(for: "SUPublicEDKey", in: infoDictionary),
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

    /// Sparkle refuses plain http feeds; a URL broken by the `//` comment rule has no host.
    private static func httpsURL(_ value: String) -> URL? {
        guard
            let components = URLComponents(string: value),
            components.scheme == "https",
            let host = components.host,
            !host.isEmpty
        else { return nil }

        return components.url
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
