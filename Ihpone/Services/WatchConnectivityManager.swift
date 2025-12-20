import Foundation
import Combine
import WatchConnectivity

@MainActor
final class PhoneWatchConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneWatchConnectivityManager()

    @Published var isWatchReachable: Bool = false
    @Published var liveHeartRate: Double = 0
    @Published var liveHRV: Double = 0

    private var session: WCSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            self.session = session
            session.delegate = self
            session.activate()
            refreshReachability(using: session)
        }
    }

    func startMirroringLiveData() {
        resetLiveMetrics()
        requestConnectionPing()
    }

    func stopMirroringLiveData() {
        resetLiveMetrics()
    }

    func startSleepSession(id: UUID) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["command": "startSleep", "sessionId": id.uuidString], replyHandler: nil)
    }

    func stopSleepSession(id: UUID) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["command": "stopSleep", "sessionId": id.uuidString], replyHandler: nil)
    }
}

extension PhoneWatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            refreshReachability(using: session)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshReachability(using: session)
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshReachability(using: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            process(message: message, from: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            process(message: applicationContext, from: session)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

private extension PhoneWatchConnectivityManager {
    func refreshReachability(using session: WCSession) {
        let paired = session.isPaired && session.isWatchAppInstalled
        let reachable = session.isReachable || (session.activationState == .activated && paired)
        isWatchReachable = reachable
    }

    func requestConnectionPing() {
        guard let session, session.isReachable else { return }
        session.sendMessage(["command": "ping"], replyHandler: nil, errorHandler: nil)
    }

    func resetLiveMetrics() {
        liveHeartRate = 0
        liveHRV = 0
    }

    func process(message: [String: Any], from session: WCSession) {
        if let connected = message["connected"] as? Bool {
            isWatchReachable = connected
        }

        if let status = message["status"] as? String, status == WatchSideStatus.inactive.rawValue {
            isWatchReachable = false
        }

        if let heartRate = message["heartRate"] as? Double {
            liveHeartRate = heartRate
        }

        if let hrv = message["hrv"] as? Double {
            liveHRV = hrv
        }

        refreshReachability(using: session)
    }
}

private enum WatchSideStatus: String {
    case inactive
    case ready
    case tracking
}
