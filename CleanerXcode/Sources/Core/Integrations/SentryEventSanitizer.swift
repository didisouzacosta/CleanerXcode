//
//  SentryEventSanitizer.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Sentry

/// Scrubs events and breadcrumbs before they leave the Mac. Sentry calls these functions on its own
/// threads, so everything here is `nonisolated` and keeps no state.
nonisolated enum SentryEventSanitizer {

    // MARK: - Public Properties

    static let maxTextLength = 1024

    // MARK: - Public Methods

    static func sanitize(_ event: Event) -> Event? {
        event.user = nil
        event.serverName = nil

        if let formatted = event.message?.formatted {
            event.message = SentryMessage(formatted: sanitize(text: formatted))
        }

        event.context = sanitize(context: event.context)
        event.extra = event.extra?.mapValues(sanitize(value:))
        event.tags = event.tags?.mapValues { sanitize(text: $0) }
        event.breadcrumbs = event.breadcrumbs?.compactMap(sanitizeBreadcrumb)

        for exception in event.exceptions ?? [] {
            exception.value = exception.value.map { sanitize(text: $0) }
            exception.mechanism?.desc = exception.mechanism?.desc.map { sanitize(text: $0) }
            exception.mechanism?.data = exception.mechanism?.data?.mapValues(sanitize(value:))
            sanitize(exception.stacktrace)
        }

        for thread in event.threads ?? [] {
            sanitize(thread.stacktrace)
        }

        sanitize(event.stacktrace)

        for image in event.debugMeta ?? [] {
            image.codeFile = image.codeFile.map { sanitize(text: $0) }
        }

        return event
    }

    static func sanitizeBreadcrumb(_ breadcrumb: Breadcrumb) -> Breadcrumb? {
        breadcrumb.message = breadcrumb.message.map { sanitize(text: $0) }

        for (key, value) in breadcrumb.data ?? [:] {
            breadcrumb.setData(value: sanitize(value: value), key: key)
        }

        return breadcrumb
    }

    /// Temporary paths (where tools like AI agents write) are dropped entirely; the home folder
    /// becomes `~` so the rest of the path still helps to debug.
    static func sanitize(text: String) -> String {
        let withoutTemporaryPaths = text.replacing(#/(?:/private)?/var/folders/[^\s"']*/#, with: "<tmp>")
        let withoutHome = withoutTemporaryPaths.replacing(
            #/(?i)(?:/System/Volumes/Data)?/Users/(?!Shared(?:[/\s"']|$))[^/\s"']+/#,
            with: "~"
        )

        return String(withoutHome.prefix(maxTextLength))
    }

    // MARK: - Private Methods

    /// Also drops `app.device_app_hash`, which the SDK derives from the `en0` MAC address and the model.
    private static func sanitize(context: [String: [String: Any]]?) -> [String: [String: Any]]? {
        guard let context else { return nil }

        var sanitized = context.mapValues { $0.mapValues(sanitize(value:)) }
        sanitized["app"]?["device_app_hash"] = nil

        return sanitized
    }

    private static func sanitize(value: Any) -> Any {
        switch value {
        case let text as String:
            sanitize(text: text)
        case let values as [String: Any]:
            values.mapValues(sanitize(value:))
        case let items as [Any]:
            items.map(sanitize(value:))
        default:
            value
        }
    }

    private static func sanitize(_ stacktrace: SentryStacktrace?) {
        for frame in stacktrace?.frames ?? [] {
            frame.fileName = frame.fileName.map { sanitize(text: $0) }
            frame.package = frame.package.map { sanitize(text: $0) }
        }
    }

}
