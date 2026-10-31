//
//  SentryEventSanitizerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Sentry
import Testing
@testable import CleanerXcode

struct SentryEventSanitizerTests {

    // MARK: - Public Methods

    @Test
    func homeFolderBecomesTilde() {
        let text = "Failed at /Users/adriano/Library/Developer/Xcode/DerivedData/App-abc"

        #expect(SentryEventSanitizer.sanitize(text: text) == "Failed at ~/Library/Developer/Xcode/DerivedData/App-abc")
    }

    @Test
    func homeFolderOnTheDataVolumeAndBareHomeBecomeTilde() {
        #expect(SentryEventSanitizer.sanitize(text: "/System/Volumes/Data/Users/adriano/x") == "~/x")
        #expect(SentryEventSanitizer.sanitize(text: "home is /Users/adriano") == "home is ~")
        #expect(SentryEventSanitizer.sanitize(text: "file:///Users/adriano/a.txt") == "file://~/a.txt")
    }

    @Test
    func sharedUsersFolderIsKept() {
        #expect(SentryEventSanitizer.sanitize(text: "/Users/Shared/cache") == "/Users/Shared/cache")
    }

    @Test
    func temporaryPathsBecomeAPlaceholder() {
        let privateTemp = "rm /private/var/folders/ab/cd123/T/claude-501/chat.json failed"
        let temp = "open '/var/folders/ab/cd123/C/com.app/x' denied"

        #expect(SentryEventSanitizer.sanitize(text: privateTemp) == "rm <tmp> failed")
        #expect(SentryEventSanitizer.sanitize(text: temp) == "open '<tmp>' denied")
    }

    @Test
    func longTextIsTruncated() {
        let text = String(repeating: "a", count: SentryEventSanitizer.maxTextLength + 50)

        #expect(SentryEventSanitizer.sanitize(text: text).count == SentryEventSanitizer.maxTextLength)
    }

    @Test
    func eventLosesUserServerNameAndPaths() throws {
        let event = Event(level: .error)
        event.user = User(userId: "someone")
        event.serverName = "Adrianos-MacBook-Pro"
        event.message = SentryMessage(formatted: "Cannot remove /Users/adriano/Library/Caches/x")
        event.extra = ["path": "/private/var/folders/ab/cd/T/file", "count": 3]
        event.tags = ["folder": "/Users/adriano/Developer"]
        event.breadcrumbs = [makeBreadcrumb(message: "Opened /Users/adriano/Desktop")]

        let frame = Frame()
        frame.fileName = "/Users/adriano/Projects/CleanerXcode/CleanerStore.swift"
        frame.package = "/Users/adriano/Applications/CleanerXcode.app/Contents/MacOS/CleanerXcode"
        let exception = Exception(value: "No permission: /Users/adriano/Library/x", type: "CleanupError")
        exception.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        event.exceptions = [exception]

        let thread = SentryThread(threadId: 1)
        thread.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        event.threads = [thread]

        let image = DebugMeta()
        image.codeFile = "/Users/adriano/Applications/CleanerXcode.app/Contents/MacOS/CleanerXcode"
        event.debugMeta = [image]

        let sanitized = try #require(SentryEventSanitizer.sanitize(event))

        #expect(sanitized.user == nil)
        #expect(sanitized.serverName == nil)
        #expect(sanitized.message?.formatted == "Cannot remove ~/Library/Caches/x")
        #expect(sanitized.extra?["path"] as? String == "<tmp>")
        #expect(sanitized.extra?["count"] as? Int == 3)
        #expect(sanitized.tags?["folder"] == "~/Developer")
        #expect(sanitized.breadcrumbs?.first?.message == "Opened ~/Desktop")
        #expect(sanitized.exceptions?.first?.value == "No permission: ~/Library/x")
        #expect(sanitized.exceptions?.first?.stacktrace?.frames.first?
            .fileName == "~/Projects/CleanerXcode/CleanerStore.swift")
        #expect(sanitized.exceptions?.first?.stacktrace?.frames.first?
            .package == "~/Applications/CleanerXcode.app/Contents/MacOS/CleanerXcode")
        #expect(sanitized.threads?.first?.stacktrace?.frames.first?
            .fileName == "~/Projects/CleanerXcode/CleanerStore.swift")
        #expect(sanitized.debugMeta?.first?.codeFile == "~/Applications/CleanerXcode.app/Contents/MacOS/CleanerXcode")
    }

    @Test
    func homeFolderMatchIgnoresCase() {
        #expect(SentryEventSanitizer.sanitize(text: "/users/adriano/x") == "~/x")
    }

    /// NSError and NSException `userInfo` land in `context["user info"]`, and crash messages in
    /// `mechanism.data`, before `beforeSend` runs.
    @Test
    func contextsAndMechanismsAreSanitized() throws {
        let event = Event(level: .error)
        event.context = [
            "user info": ["NSFilePath": "/Users/adriano/Library/x", "nested": ["/var/folders/ab/cd/T/y"]],
            "os": ["name": "macOS"],
        ]

        let mechanism = Mechanism(type: "nsexception")
        mechanism.desc = "Crashed reading /Users/adriano/Desktop/a"
        mechanism.data = ["crash_info_messages": ["fatal at /Users/adriano/Projects/b"]]
        let exception = Exception(value: "boom", type: "NSException")
        exception.mechanism = mechanism
        event.exceptions = [exception]

        let sanitized = try #require(SentryEventSanitizer.sanitize(event))
        let userInfo = sanitized.context?["user info"]
        let sanitizedMechanism = sanitized.exceptions?.first?.mechanism

        #expect(userInfo?["NSFilePath"] as? String == "~/Library/x")
        #expect(userInfo?["nested"] as? [String] == ["<tmp>"])
        #expect(sanitized.context?["os"]?["name"] as? String == "macOS")
        #expect(sanitizedMechanism?.desc == "Crashed reading ~/Desktop/a")
        #expect(sanitizedMechanism?.data?["crash_info_messages"] as? [String] == ["fatal at ~/Projects/b"])
    }

    /// `device_app_hash` is a SHA1 of the `en0` MAC address, the model and the bundle ID: a stable
    /// hardware-derived identifier.
    @Test
    func hardwareDerivedHashIsRemoved() throws {
        let event = Event(level: .error)
        event.context = ["app": ["device_app_hash": "abc123", "app_version": "1.0.0"]]

        let sanitized = try #require(SentryEventSanitizer.sanitize(event))

        #expect(sanitized.context?["app"]?["device_app_hash"] == nil)
        #expect(sanitized.context?["app"]?["app_version"] as? String == "1.0.0")
    }

    @Test
    func breadcrumbMessageAndDataAreSanitized() throws {
        let breadcrumb = makeBreadcrumb(message: "Deleted /Users/adriano/Library/Developer/Xcode/Archives")
        breadcrumb.setData(value: "file:///Users/adriano/a", key: "url")
        breadcrumb.setData(value: 2, key: "items")

        let sanitized = try #require(SentryEventSanitizer.sanitizeBreadcrumb(breadcrumb))

        #expect(sanitized.message == "Deleted ~/Library/Developer/Xcode/Archives")
        #expect(sanitized.data?["url"] as? String == "file://~/a")
        #expect(sanitized.data?["items"] as? Int == 2)
    }

    // MARK: - Private Methods

    private func makeBreadcrumb(message: String) -> Breadcrumb {
        let breadcrumb = Breadcrumb(level: .info, category: "cleanup")
        breadcrumb.message = message
        return breadcrumb
    }

}
