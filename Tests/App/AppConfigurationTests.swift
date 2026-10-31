//
//  AppConfigurationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct AppConfigurationTests {

    // MARK: - Public Methods

    @Test
    func readsVersionFileURLFromInfoDictionary() {
        let configuration = AppConfiguration(
            infoDictionary: ["VERSION_FILE_URL": "https://example.com/version.json"]
        )

        #expect(configuration.versionFileURL == URL(string: "https://example.com/version.json"))
    }

    @Test
    func treatsEmptyVersionFileURLAsNotConfigured() {
        let configuration = AppConfiguration(infoDictionary: ["VERSION_FILE_URL": ""])

        #expect(configuration.versionFileURL == nil)
    }

    @Test
    func treatsMissingVersionFileURLAsNotConfigured() {
        let configuration = AppConfiguration(infoDictionary: [:])

        #expect(configuration.versionFileURL == nil)
    }

    @Test
    func readsObservabilityKeysFromInfoDictionary() {
        let configuration = AppConfiguration(
            infoDictionary: [
                "HIMETRICA_API_KEY": "hm_pk_123",
                "SENTRY_DSN": "https://key@o1.ingest.sentry.io/2",
            ]
        )

        #expect(configuration.himetricaAPIKey == "hm_pk_123")
        #expect(configuration.sentryDSN == "https://key@o1.ingest.sentry.io/2")
    }

    @Test
    func treatsEmptyObservabilityKeysAsNotConfigured() {
        let configuration = AppConfiguration(
            infoDictionary: ["HIMETRICA_API_KEY": "", "SENTRY_DSN": "  "]
        )

        #expect(configuration.himetricaAPIKey == nil)
        #expect(configuration.sentryDSN == nil)
    }

    @Test
    func treatsMalformedSentryDSNAsNotConfigured() {
        for dsn in ["https:", "https://", "not a dsn", "ftp://key@o1.ingest.sentry.io/2"] {
            let configuration = AppConfiguration(infoDictionary: ["SENTRY_DSN": dsn])

            #expect(configuration.sentryDSN == nil, "\(dsn) should not be accepted")
        }
    }

    @Test
    func readsTheBundleReleaseInformation() {
        let configuration = AppConfiguration(
            infoDictionary: [
                "CFBundleIdentifier": "didisouzacosta.CleanerXcode",
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "120",
            ]
        )

        #expect(configuration.bundleIdentifier == "didisouzacosta.CleanerXcode")
        #expect(configuration.version == "1.0.0")
        #expect(configuration.build == "120")
    }

    @Test
    func treatsUnexpandedBuildSettingsAsNotConfigured() {
        let configuration = AppConfiguration(
            infoDictionary: [
                "HIMETRICA_API_KEY": "$(HIMETRICA_API_KEY)",
                "SENTRY_DSN": "$(SENTRY_DSN)",
                "VERSION_FILE_URL": "$(VERSION_FILE_URL)",
            ]
        )

        #expect(configuration.himetricaAPIKey == nil)
        #expect(configuration.sentryDSN == nil)
        #expect(configuration.versionFileURL == nil)
    }

    @Test
    func infoPlistOnlyAddsTheExpectedCustomKeys() {
        let applePrefixes = ["CF", "DT", "LS", "NS", "BuildMachine"]
        let infoDictionary = Bundle.main.infoDictionary ?? [:]
        let customKeys = Set(infoDictionary.keys.filter { key in
            !applePrefixes.contains { key.hasPrefix($0) }
        })

        #expect(customKeys == ["HIMETRICA_API_KEY", "SENTRY_DSN", "VERSION_FILE_URL"])
    }

}
