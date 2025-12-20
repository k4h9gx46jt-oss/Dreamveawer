import SwiftUI

@main
struct DreamWeaverWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var connectivityManager = WatchSideConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationView {
                WatchContentView()
            }
            .environmentObject(workoutManager)
            .environmentObject(connectivityManager)
        }
    }
}
