//
//  DreamWeaverApp.swift
//  DreamWeaver
//
//  Created by Gazsik Jozsef 6035 ED on 20.12.2025.
//

import SwiftUI

@main
struct DreamWeaverApp: App {
    @StateObject private var dataStore: SleepDataStore
    @StateObject private var connectivityManager: PhoneWatchConnectivityManager

    init() {
        let store = SleepDataStore()
        let manager = PhoneWatchConnectivityManager.shared
        manager.registerDreamStore(store)
        _dataStore = StateObject(wrappedValue: store)
        _connectivityManager = StateObject(wrappedValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(connectivityManager)
        }
    }
}
