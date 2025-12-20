import SwiftUI
import WatchKit

@main
struct DreamWeaverWatchApp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var extensionDelegate
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
