//
//  DreamWeaverApp.swift
//  DreamWeaver
//
//  Created by Gazsik Jozsef 6035 ED on 20.12.2025.
//

import SwiftUI

@main
struct DreamWeaverApp: App {
    @StateObject private var dataStore = SleepDataStore()
    @StateObject private var connectivityManager = PhoneWatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(connectivityManager)
        }
    }
}
