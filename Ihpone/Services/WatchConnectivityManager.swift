import Foundation
import Combine
import WatchConnectivity
#if os(iOS)
import UIKit
#endif

@MainActor
final class PhoneWatchConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneWatchConnectivityManager()

    @Published var isWatchReachable: Bool = false
    @Published var liveHeartRate: Double = 0
    @Published var liveHRV: Double = 0
    @Published var sleepSamples: [BiosignalDataPoint] = []
    @Published var remWindows: [SleepREMWindow] = []
    @Published var remoteSessionStart: Date?
    @Published var remoteSessionEndedAt: Date?
    @Published var remoteSessionId: UUID?

    private var session: WCSession?
    private var currentREMStart: Date?

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

    func attemptReconnect() {
        guard let session else { return }
        session.activate()
        refreshReachability(using: session)
        requestConnectionPing()
    }

    func openWatchAppSettings() {
        #if os(iOS)
        if let url = URL(string: "itms-watchs://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
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
        sleepSamples = []
        remWindows = []
        currentREMStart = nil
    }

    func process(message: [String: Any], from session: WCSession) {
        if let event = message["event"] as? String {
            handleEvent(event, payload: message)
            refreshReachability(using: session)
            return
        }
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

    func handleEvent(_ event: String, payload: [String: Any]) {
        switch event {
        case "sleepStart":
            resetLiveMetrics()
            if let idString = payload["sessionId"] as? String,
               let startInterval = payload["start"] as? Double,
               let uuid = UUID(uuidString: idString) {
                remoteSessionId = uuid
                remoteSessionStart = Date(timeIntervalSince1970: startInterval)
                remoteSessionEndedAt = nil
            }
        case "sleepEnd":
            if let endInterval = payload["end"] as? Double,
               let startInterval = payload["start"] as? Double {
                let endDate = Date(timeIntervalSince1970: endInterval)
                finalizeREMWindow(until: endDate)
                if let list = payload["samples"] as? [[String: Double]] {
                    sleepSamples = list.compactMap { dict in
                        guard let timestamp = dict["timestamp"],
                              let heartRate = dict["heartRate"],
                              let hrv = dict["hrv"] else { return nil }
                        return BiosignalDataPoint(timestamp: Date(timeIntervalSince1970: timestamp), heartRate: heartRate, hrv: hrv, movement: 0)
                    }
                }
                remoteSessionId = UUID(uuidString: payload["sessionId"] as? String ?? "")
                remoteSessionStart = nil
                remoteSessionEndedAt = endDate
                currentREMStart = nil
            }
        case "sample":
            guard let timestamp = payload["timestamp"] as? Double,
                  let heartRate = payload["heartRate"] as? Double,
                  let hrv = payload["hrv"] as? Double else { return }
            let sample = BiosignalDataPoint(timestamp: Date(timeIntervalSince1970: timestamp), heartRate: heartRate, hrv: hrv, movement: 0)
            sleepSamples.append(sample)
            if sleepSamples.count > 720 { sleepSamples.removeFirst() }
            liveHeartRate = heartRate
            liveHRV = hrv
            if let remState = payload["remState"] as? String {
                updateREM(with: sample.timestamp, state: remState)
            }
        default:
            break
        }
    }

    func updateREM(with timestamp: Date, state: String) {
        if state == REMState.rem.rawValue {
            if currentREMStart == nil {
                currentREMStart = timestamp
            }
        } else if let start = currentREMStart {
            let window = SleepREMWindow(start: start, end: timestamp)
            remWindows.append(window)
            currentREMStart = nil
        }
    }

    func finalizeREMWindow(until end: Date) {
        if let start = currentREMStart {
            remWindows.append(SleepREMWindow(start: start, end: end))
            currentREMStart = nil
        }
    }
}

private enum WatchSideStatus: String {
    case inactive
    case ready
    case tracking
}

private enum REMState: String {
    case light
    case deep
    case rem
}
