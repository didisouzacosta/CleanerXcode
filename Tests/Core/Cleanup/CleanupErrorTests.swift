//
//  CleanupErrorTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CleanupErrorTests {

    // MARK: - Public Methods

    @Test
    func permissionErrorsMapToPermissionDenied() {
        #expect(CleanupError(POSIXError(.EACCES)) == .permissionDenied)
        #expect(CleanupError(POSIXError(.EPERM)) == .permissionDenied)
        #expect(CleanupError(CocoaError(.fileWriteNoPermission)) == .permissionDenied)
        #expect(CleanupError(CocoaError(.fileReadNoPermission)) == .permissionDenied)
    }

    @Test
    func busyMapsToInUseAndMissingMapsToNotFound() {
        #expect(CleanupError(POSIXError(.EBUSY)) == .inUse)
        #expect(CleanupError(POSIXError(.ENOENT)) == .notFound)
        #expect(CleanupError(CocoaError(.fileNoSuchFile)) == .notFound)
    }

    @Test
    func cocoaErrorsWrappingPOSIXErrorsUseTheUnderlyingCode() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.fileWriteUnknown.rawValue,
            userInfo: [NSUnderlyingErrorKey: POSIXError(.EBUSY)]
        )

        #expect(CleanupError(error) == .inUse)
    }

    @Test
    func cancellationMapsToCancelled() {
        #expect(CleanupError(CancellationError()) == .cancelled)
    }

    @Test
    func cleanupErrorsArePassedThrough() {
        #expect(CleanupError(CleanupError.timedOut) == .timedOut)
    }

    @Test
    func posixCodesOutsideTheInt32RangeDoNotCrash() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(Int32.max) + 1)

        #expect(CleanupError(error) == .unknown(domain: NSPOSIXErrorDomain, code: Int(Int32.max) + 1))
    }

    @Test
    func anythingElseKeepsOnlyItsDomainAndCode() {
        let error = NSError(domain: "SomeDomain", code: 42, userInfo: [NSFilePathErrorKey: "/Users/tester/secret"])

        #expect(CleanupError(error) == .unknown(domain: "SomeDomain", code: 42))
    }

}
