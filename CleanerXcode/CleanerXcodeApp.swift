//
//  CleanerXcodeApp.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@main
struct CleanerXcodeApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image("iconClear")
        }
        .menuBarExtraStyle(.window)
    }
}
