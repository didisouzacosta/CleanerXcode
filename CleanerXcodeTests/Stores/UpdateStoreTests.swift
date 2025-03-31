//
//  UpdateStoreTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 23/03/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct UpdateStoreTests {

    @Test func ensureUpdateVersionAfterCheckUpdates() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.0.1",
            build: "1",
            fullVersion: "0.0.1.1"
        ) {
            .init(
                version: "0.0.1",
                build: "1",
                downloadURL: .fake
            )
        }
        
        let store = UpdateStore(applicationInfoStub)
        
        store.checkUpdates()
        
        waitUntil {
            store.version != nil
        }
        
        #expect(store.version?.version == "0.0.1")
        #expect(store.version?.build == "1")
    }
    
    @Test func hasUpdatesShouldNotBeTrueWhenLocalVersionIsGreatherThanRemoteVersion() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.1.0",
            build: "100",
            fullVersion: "0.1.0.100"
        ) {
            .init(
                version: "0.0.1",
                build: "1",
                downloadURL: .fake
            )
        }
        
        let store = UpdateStore(applicationInfoStub)
        
        store.checkUpdates()
        
        waitUntil {
            store.version != nil
        }
        
        #expect(store.hasUpdate.value == false)
    }
    
    @Test func hasUpdatesShouldNotBeTrueWhenLocalVersionIsEqualThanRemoteVersion() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.1.0",
            build: "100",
            fullVersion: "0.1.0.100"
        ) {
            .init(
                version: "0.1.0",
                build: "100",
                downloadURL: .fake
            )
        }
        
        let store = UpdateStore(applicationInfoStub)
        
        store.checkUpdates()
        
        waitUntil {
            store.version != nil
        }
        
        #expect(store.hasUpdate.value == false)
    }
    
    @Test func hasUpdatesShouldBeTrueWhenLocalVersionIsLessThanRemoteVersion() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.0.1",
            build: "1",
            fullVersion: "0.0.1.100"
        ) {
            .init(
                version: "0.1.0",
                build: "100",
                downloadURL: .fake
            )
        }
        
        let store = UpdateStore(applicationInfoStub)
        
        store.checkUpdates()
        
        waitUntil {
            store.version != nil && store.hasUpdate.value == true
        }
        
        #expect(store.hasUpdate.value == true)
    }

}

fileprivate struct ApplicationInforStub: ApplicationInfo {
    
    typealias Handler = () throws -> Version
    
    var version: String
    var build: String
    var fullVersion: String
    var remoteVersionHandler: Handler
    
    init(
        version: String,
        build: String,
        fullVersion: String,
        remoteVersionHandler: @escaping Handler
    ) {
        self.version = version
        self.build = build
        self.fullVersion = fullVersion
        self.remoteVersionHandler = remoteVersionHandler
    }
    
    func loadLatestVersionFromRemote() async throws -> Version {
        try remoteVersionHandler()
    }
    
}

fileprivate extension URL {
    
    static let fake = URL(string: "https://fake.url.com")!
    
}
