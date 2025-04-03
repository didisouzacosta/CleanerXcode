//
//  UpdateStore.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 28/03/25.
//

import SwiftUI

@Observable
final class UpdateStore {
    
    // MARK: - Public Variables
    
    private(set) var hasUpdate = StateValue(false)
    
    private(set) var version: Version? {
        didSet {
            compareVersions()
        }
    }
    
    // MARK: - Private Variables
    
    private let applicationInfo: ApplicationInfo
    
    // MARK: - Initializers
    
    public init(_ applicationInfo: ApplicationInfo) {
        self.applicationInfo = applicationInfo
    }
    
    // MARK: - Public Methods
    
    func checkUpdates() {
        hasUpdate.isLoading = true
        
        Task { @MainActor in
            do {
                version = try await applicationInfo.loadLatestVersionFromRemote()
            } catch {
                hasUpdate.error = error
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func compareVersions() {
        guard let version else { return }
        let status = applicationInfo.version.toVersionInt() < version.version.toVersionInt()
        hasUpdate.value = status
    }
    
}

fileprivate extension String {
    
    func toVersionInt() -> Int {
        Int(self.split(separator: ".").joined()) ?? 0
    }
    
}

extension EnvironmentValues {
    
    @Entry var updateStore = UpdateStore(Bundle.main)
    
}
