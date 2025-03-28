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
    private let versionFileURL = URL(string: "https://github.com/didisouzacosta/CleanerXcode/raw/refs/heads/main/resources/version.json")!
    
    // MARK: - Initializers
    
    public init(_ applicationInfo: ApplicationInfo) {
        self.applicationInfo = applicationInfo
    }
    
    // MARK: - Public Methods
    
    func checkUpdates() {
        hasUpdate.state = .isLoading
        
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
        hasUpdate.state = .success(version.version < applicationInfo.version)
    }
    
}

extension EnvironmentValues {
    
    @Entry var updateStore = UpdateStore(Bundle.main)
    
}
