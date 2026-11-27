//
//  ErrorReportingConfiguration.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated struct ErrorReportingConfiguration: Equatable, Sendable {

    // MARK: - Public Properties

    let dsn: String
    let environment: String
    let releaseName: String
    let dist: String
    let sampleRate: Double
    let tracesSampleRate: Double

    // MARK: - Initializers

    /// Every error is sent and performance tracing stays off in both environments.
    init(dsn: String, bundleIdentifier: String?, version: String?, build: String?, isDebug: Bool) {
        let build = build ?? "unknown"

        self.dsn = dsn
        self.environment = isDebug ? "debug" : "production"
        self.releaseName = "\(bundleIdentifier ?? "com.didisouzacosta.CleanerXcode")@\(version ?? "unknown")+\(build)"
        self.dist = build
        self.sampleRate = 1.0
        self.tracesSampleRate = 0.0
    }

}
