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
        @Bindable var bindablePreferences = preferences
        
        VStack(alignment: .leading, spacing: 0) {
            Button {
                test.wrappedValue.toggle()
            } label: {
                Label("Home", systemImage: "chevron.backward")
            }
            .buttonStyle(.plain)
            .padding([.top, .trailing, .leading])

            Form {
                Section("Permissions") {
                    Toggle("Remove Derived Data", isOn: $bindablePreferences.canRemoveDerivedData.value)
                    Toggle("Remove Caches", isOn: $bindablePreferences.canRemoveCaches.value)
                    Toggle("Remove Device Support", isOn: $bindablePreferences.canRemoveDeviceSupport.value)
                    Toggle("Remove Old Simulators", isOn: $bindablePreferences.canRemoveOldSimulators.value)
                }
                
                Section("About") {
                    Text("Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.")
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
