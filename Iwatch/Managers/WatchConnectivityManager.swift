import Foundation
import WatchConnectivity

@MainActor
final class WatchSideConnectivityManager: NSObject, ObservableObject {
    enum ConnectionState: String {
        case inactive
        case ready
        case tracking
    }

    static let shared = WatchSideConnectivityManager()
    @Published var lastCommand: String = ""
    @Published private(set) var currentState: ConnectionState = .inactive

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            Task { await sendConnectionState(.ready) }
        }
    }

    func sendSnapshot(heartRate: Double, hrv: Double) {
        let payload: [String: Any] = [
            "heartRate": heartRate,
            "hrv": hrv,
            "timestamp": Date().timeIntervalSince1970,
            "connected": true
        ]
        send(message: payload)
    }

    func sendConnectionState(_ state: ConnectionState) {
        currentState = state
        let payload: [String: Any] = [
            "status": state.rawValue,
            "connected": state != .inactive
        ]
        send(message: payload)
    }

    private func send(message: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            try? session.updateApplicationContext(message)
        }
    }
}

extension WatchSideConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            if let command = message["command"] as? String {
                lastCommand = command
                if command == "ping" {
                    sendConnectionState(currentState == .inactive ? .ready : currentState)
                }
            }
        }
    }
}
