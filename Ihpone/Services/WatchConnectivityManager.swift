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
    @Published var liveSpO2: Double = 0
    @Published var liveRespiratoryRate: Double = 0
    @Published var liveECGConfidence: Double = 0
    @Published var liveHypertensionRisk: Double = 0
    @Published var liveTemperatureDelta: Double = 0
    @Published var liveSleepScore: Double = 0
    @Published var liveNoiseExposure: Double = 0
    @Published var liveApneaRisk: Double = 0
    @Published var liveSleepStage: String = "Light"
    @Published var sleepSamples: [BiosignalDataPoint] = []
    @Published var remWindows: [SleepREMWindow] = []
    @Published var remoteSessionStart: Date?
    @Published var remoteSessionEndedAt: Date?
    @Published var remoteSessionId: UUID?

    private var session: WCSession?
    private var currentREMStart: Date?
    private var watchReportedConnected = false
    private var dreamStore: SleepDataStore?
    private var pendingRemoteSessions: [RemoteSleepSessionResult] = []
    private var lastStatusProbeDate: Date?

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
        requestWatchStatusSnapshot(force: true)
    }

    func openWatchAppSettings() {
        #if os(iOS)
        if let url = URL(string: "itms-watchs://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    func registerDreamStore(_ store: SleepDataStore) {
        dreamStore = store
        guard !pendingRemoteSessions.isEmpty else { return }
        let bufferedSessions = pendingRemoteSessions
        pendingRemoteSessions.removeAll()
        Task {
            for session in bufferedSessions {
                await store.ingestRemoteSession(session)
            }
        }
    }

    func requestWatchStatusSnapshot(force: Bool = false) {
        guard let session else { return }
        guard session.activationState == .activated else { return }
        if !force, let last = lastStatusProbeDate, Date().timeIntervalSince(last) < 5 {
            return
        }
        guard session.isReachable else { return }
        lastStatusProbeDate = Date()
        let payload: [String: Any] = [
            "command": "watchStatusProbe",
            "timestamp": Date().timeIntervalSince1970
        ]
        session.sendMessage(payload) { [weak self] response in
            Task { @MainActor in
                self?.handleStatusSnapshot(response)
            }
        } errorHandler: { error in
            print("Watch status probe failed: \(error.localizedDescription)")
        }
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
        if isWatchReachable {
            requestWatchStatusSnapshot()
        }
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
        liveSpO2 = 0
        liveRespiratoryRate = 0
        liveECGConfidence = 0
        liveHypertensionRisk = 0
        liveTemperatureDelta = 0
        liveSleepScore = 0
        liveNoiseExposure = 0
        liveApneaRisk = 0
        liveSleepStage = "Light"
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

        if let spo2 = message["spo2"] as? Double {
            liveSpO2 = spo2
        }

        if let respiratoryRate = message["respiratoryRate"] as? Double {
            liveRespiratoryRate = respiratoryRate
        }

        if let ecg = message["ecgConfidence"] as? Double {
            liveECGConfidence = ecg
        }

        if let hypertension = message["hypertensionRisk"] as? Double {
            liveHypertensionRisk = hypertension
        }

        if let temperature = message["temperatureDelta"] as? Double {
            liveTemperatureDelta = temperature
        }

        if let sleepScore = message["sleepScore"] as? Double {
            liveSleepScore = sleepScore
        }

        if let noise = message["noiseExposure"] as? Double {
            liveNoiseExposure = noise
        }

        if let apnea = message["apneaRisk"] as? Double {
            liveApneaRisk = apnea
        }

        if message["event"] == nil, message["tracking"] != nil {
            handleStatusSnapshot(message)
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
            liveSleepStage = "Light"
        case "sleepEnd":
            guard let endInterval = payload["end"] as? Double else { return }
            let endDate = Date(timeIntervalSince1970: endInterval)
            finalizeREMWindow(until: endDate)
            var decodedSamples: [BiosignalDataPoint] = []
            if let list = payload["samples"] as? [[String: Double]] {
                decodedSamples = list.compactMap { dict in
                    guard let timestamp = dict["timestamp"],
                          let heartRate = dict["heartRate"],
                          let hrv = dict["hrv"] else { return nil }
                    return BiosignalDataPoint(
                        timestamp: Date(timeIntervalSince1970: timestamp),
                        heartRate: heartRate,
                        hrv: hrv,
                        movement: 0,
                        spo2: dict["spo2"] ?? 0,
                        respiratoryRate: dict["respiratoryRate"] ?? 0,
                        ecgConfidence: dict["ecgConfidence"] ?? 0,
                        hypertensionRisk: dict["hypertensionRisk"] ?? 0,
                        wristTemperatureDelta: dict["temperatureDelta"] ?? 0,
                        sleepScore: dict["sleepScore"] ?? 0,
                        noiseExposure: dict["noiseExposure"] ?? 0,
                        apneaRisk: dict["apneaRisk"] ?? 0
                    )
                }
                sleepSamples = decodedSamples
                if let last = decodedSamples.last {
                    liveSleepScore = last.sleepScore
                    liveSpO2 = last.spo2
                    liveRespiratoryRate = last.respiratoryRate
                    liveECGConfidence = last.ecgConfidence
                    liveHypertensionRisk = last.hypertensionRisk
                    liveTemperatureDelta = last.wristTemperatureDelta
                    liveNoiseExposure = last.noiseExposure
                    liveApneaRisk = last.apneaRisk
                }
            }
            let sessionIdentifier = UUID(uuidString: payload["sessionId"] as? String ?? "")
            let startInterval = payload["start"] as? Double
            let startDate = startInterval.map { Date(timeIntervalSince1970: $0) } ?? remoteSessionStart ?? Date(timeIntervalSince1970: endInterval)
            remoteSessionId = sessionIdentifier
            remoteSessionStart = nil
            remoteSessionEndedAt = endDate
            currentREMStart = nil
            deliverRemoteSessionResult(RemoteSleepSessionResult(sessionId: sessionIdentifier,
                                                                startedAt: startDate,
                                                                endedAt: endDate,
                                                                samples: decodedSamples))
        case "sample":
            guard let timestamp = payload["timestamp"] as? Double,
                  let heartRate = payload["heartRate"] as? Double,
                  let hrv = payload["hrv"] as? Double else { return }
            let sample = BiosignalDataPoint(
                timestamp: Date(timeIntervalSince1970: timestamp),
                heartRate: heartRate,
                hrv: hrv,
                movement: 0,
                spo2: payload["spo2"] as? Double ?? liveSpO2,
                respiratoryRate: payload["respiratoryRate"] as? Double ?? liveRespiratoryRate,
                ecgConfidence: payload["ecgConfidence"] as? Double ?? liveECGConfidence,
                hypertensionRisk: payload["hypertensionRisk"] as? Double ?? liveHypertensionRisk,
                wristTemperatureDelta: payload["temperatureDelta"] as? Double ?? liveTemperatureDelta,
                sleepScore: payload["sleepScore"] as? Double ?? liveSleepScore,
                noiseExposure: payload["noiseExposure"] as? Double ?? liveNoiseExposure,
                apneaRisk: payload["apneaRisk"] as? Double ?? liveApneaRisk
            )
            sleepSamples.append(sample)
            if sleepSamples.count > 720 { sleepSamples.removeFirst() }
            liveHeartRate = heartRate
            liveHRV = hrv
            liveSpO2 = sample.spo2
            liveRespiratoryRate = sample.respiratoryRate
            liveECGConfidence = sample.ecgConfidence
            liveHypertensionRisk = sample.hypertensionRisk
            liveTemperatureDelta = sample.wristTemperatureDelta
            liveSleepScore = sample.sleepScore
            liveNoiseExposure = sample.noiseExposure
            liveApneaRisk = sample.apneaRisk
            if let remState = payload["remState"] as? String {
                updateREM(with: sample.timestamp, state: remState)
            }
        default:
            break
        }
    }

    func updateREM(with timestamp: Date, state: String) {
        liveSleepStage = stageLabel(for: state)
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
        liveSleepStage = "Idle"
    }

    private func stageLabel(for state: String) -> String {
        switch state {
        case REMState.rem.rawValue: return "REM"
        case REMState.deep.rawValue: return "Deep"
        default: return "Light"
        }
    }

    private func deliverRemoteSessionResult(_ result: RemoteSleepSessionResult) {
        if let store = dreamStore {
            Task { await store.ingestRemoteSession(result) }
        } else {
            pendingRemoteSessions.append(result)
        }
    }

    private func handleStatusSnapshot(_ payload: [String: Any]) {
        if let connected = payload["connected"] as? Bool {
            watchReportedConnected = connected
        }
        guard let tracking = payload["tracking"] as? Bool else { return }
        if tracking {
            if let idString = payload["sessionId"] as? String,
               let uuid = UUID(uuidString: idString) {
                remoteSessionId = uuid
            }
            if let startInterval = payload["start"] as? Double {
                let startDate = Date(timeIntervalSince1970: startInterval)
                remoteSessionStart = startDate
                remoteSessionEndedAt = nil
            }
        } else if remoteSessionStart != nil && remoteSessionEndedAt == nil {
            remoteSessionStart = nil
            remoteSessionId = nil
        }
        if let session {
            refreshReachability(using: session)
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
