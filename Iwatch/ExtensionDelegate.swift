import WatchKit

final class ExtensionDelegate: NSObject, WKExtensionDelegate {
    func applicationDidBecomeActive() {
        Task { await WatchSideConnectivityManager.shared.sendConnectionState(.ready) }
    }

    func applicationWillResignActive() {
        Task { await WatchSideConnectivityManager.shared.sendConnectionState(.inactive) }
    }
}
