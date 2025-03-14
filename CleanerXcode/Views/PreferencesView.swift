//
//  PreferencesView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 14/03/25.
//

import SwiftUI

struct PreferencesView: View {
    
    // MARK: - Environments
    
    @Environment(\.preferences) private var preferences
    
    // MARK: - Public Variables
    
    private var test: Binding<Bool>
    
    init(_ test: Binding<Bool>) {
        self.test = test
    }
    
    var body: some View {
        @Bindable var preferencesBindable = preferences
        
        VStack(alignment: .leading, spacing: 0) {
            Button("Back") {
                test.wrappedValue.toggle()
            }
            .padding([.top, .trailing, .leading], 18)
            
            Form {
                Section("Permissions") {
                    Toggle("Remove Derived Data", isOn: $preferencesBindable.canRemoveDerivedData)
                    Toggle("Remove Device Support", isOn: $preferencesBindable.canRemoveDeviceSupport)
                    Toggle("Remove Old Simulators", isOn: $preferencesBindable.canRemoveOldSimulators)
                    Toggle("Remove Pod Cache", isOn: $preferencesBindable.canRemovePodCache)
                }
            }
            .scrollIndicators(.never)
            .formStyle(.grouped)
        }
    }
    
}

#Preview {
    PreferencesView(.constant(false))
        .environment(\.preferences, .init())
}
