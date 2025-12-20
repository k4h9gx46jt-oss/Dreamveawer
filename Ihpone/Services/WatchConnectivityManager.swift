import Foundation
import Combine
import WatchConnectivity

@MainActor
final class PhoneWatchConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneWatchConnectivityManager()

    @Published var isWatchReachable: Bool = false
    @Published var liveHeartRate: Double = 0
    @Published var liveHRV: Double = 0

    private var timer: Timer?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func startMirroringLiveData() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.liveHeartRate = Double.random(in: 55...75)
                self.liveHRV = Double.random(in: 30...70)
            }
        }
    }

    func stopMirroringLiveData() {
        timer?.invalidate()
        timer = nil
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
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
