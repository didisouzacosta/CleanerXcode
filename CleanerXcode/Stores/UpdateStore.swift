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
        didSet { compareVersions() }
    }
    
    // MARK: - Private Variables
    
    private let applicationInfo: ApplicationInfo
    
    // MARK: - Initializers
    
    public init(_ applicationInfo: ApplicationInfo) {
        self.applicationInfo = applicationInfo
    }
    
    // MARK: - Public Methods
    
    func checkUpdates() {
        hasUpdate.state = .isLoading
        
        guard let versionFileURL = applicationInfo.versionFileURL else {
            return
        }
        
        Task { @MainActor in
            do {
                let (data, _) = try await URLSession.shared.data(from: versionFileURL)
                version = try data.decoder()
            } catch {
                hasUpdate.state = .failure(error)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func compareVersions() {
        guard let version else { return }
        let status = applicationInfo.version.toVersionInt() < version.version.toVersionInt()
        hasUpdate.state = .success(status)
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
