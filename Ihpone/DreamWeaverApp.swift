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
