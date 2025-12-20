import Foundation
import WatchConnectivity

@MainActor
final class WatchSideConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchSideConnectivityManager()
    @Published var lastCommand: String = ""

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendSnapshot(heartRate: Double, hrv: Double) {
        let payload: [String: Any] = [
            "heartRate": heartRate,
            "hrv": hrv,
            "timestamp": Date().timeIntervalSince1970
        ]
        WCSession.default.sendMessage(payload, replyHandler: nil)
    }
}

extension WatchSideConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            lastCommand = message["command"] as? String ?? ""
        }
    }
}
