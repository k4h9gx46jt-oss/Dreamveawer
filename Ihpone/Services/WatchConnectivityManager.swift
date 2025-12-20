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
    private var watchReportedConnected = false

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
        sendCommandToWatch("startSleep", extras: ["sessionId": id.uuidString])
    }

    func stopSleepSession(id: UUID) {
        sendCommandToWatch("stopSleep", extras: ["sessionId": id.uuidString])
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

      nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
          Task { @MainActor in
              if let command = message["command"] as? String, command == "statusRequest" {
                  replyHandler(statusSnapshotPayload())
                  return
              }
              process(message: message, from: session)
              replyHandler([:])
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
        isWatchReachable = reachable || watchReportedConnected
    }

    func sendCommandToWatch(_ command: String, extras: [String: Any] = [:]) {
        guard let session else { return }
        var payload = extras
        payload["command"] = command
        payload["timestamp"] = Date().timeIntervalSince1970
        payload["commandToken"] = UUID().uuidString
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Watch command send failed: \(error.localizedDescription)")
            }
        }
        enqueueCommandPayload(payload, using: session)
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

    func enqueueCommandPayload(_ payload: [String: Any], using session: WCSession) {
        if session.activationState == .activated {
            session.transferUserInfo(payload)
        } else {
            do {
                try session.updateApplicationContext(payload)
            } catch {
                print("Failed to enqueue command payload: \(error.localizedDescription)")
            }
        }
    }

    func process(message: [String: Any], from session: WCSession) {
        if let event = message["event"] as? String {
            handleEvent(event, payload: message)
            refreshReachability(using: session)
            return
        }
        if let connected = message["connected"] as? Bool {
            watchReportedConnected = connected
        }

        if let status = message["status"] as? String {
            watchReportedConnected = status != WatchSideStatus.inactive.rawValue
        }

        if let heartRate = message["heartRate"] as? Double {
            liveHeartRate = heartRate
        }

        if let hrv = message["hrv"] as? Double {
            liveHRV = hrv
        }

        refreshReachability(using: session)
    }

      func statusSnapshotPayload() -> [String: Any] {
          let tracking = remoteSessionStart != nil && remoteSessionEndedAt == nil
          var payload: [String: Any] = ["tracking": tracking]
          if tracking {
              payload["sessionId"] = remoteSessionId?.uuidString ?? ""
              payload["start"] = remoteSessionStart?.timeIntervalSince1970 ?? 0
          }
          return payload
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
            if let endInterval = payload["end"] as? Double {
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
