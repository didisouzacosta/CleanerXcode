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
            .padding(.bottom, 8)

            Form {
                Section("Permissions") {
                    Toggle("Remove Derived Data", isOn: $bindablePreferences.canRemoveDerivedData.value)
                    Toggle("Remove Caches", isOn: $bindablePreferences.canRemoveCaches.value)
                    Toggle("Remove Device Support", isOn: $bindablePreferences.canRemoveDeviceSupport.value)
                    Toggle("Remove Old Simulators", isOn: $bindablePreferences.canRemoveOldSimulators.value)
                }
                
                Section("Dedication") {
                    Text("This simple app was made for anybody ❤️ loves develop for Apple tecnologies.\n\nI'd like dedicate this app for my son Orlando and my wife Gisele.")
                }
                
                Section("Social") {
                    VStack(spacing: 16) {
                        Text("If you like, consider give me a star on Github, follow me on Twitter and Linkedin.")
                        
                        HStack(spacing: 16) {
                            Link(destination: .init(string: "https://github.com/didisouzacosta/CleanerXcode")!) {
                                Image("github.fill")
                            }
                            
                            Link(destination: .init(string: "https://x.com/didisouzacosta")!) {
                                Image("x-twitter")
                            }
                            
                            Link(destination: .init(string: "https://www.linkedin.com/in/adrianosouzacosta/")!) {
                                Image("linkedin")
                            }
                        }
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        
                        Text("Or make a donation.")
                    }
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
