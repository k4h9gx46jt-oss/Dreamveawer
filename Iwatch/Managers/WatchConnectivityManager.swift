import Foundation
import WatchConnectivity
import WatchKit

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
    private var processedCommandTokens: [String] = []
    private var processedCommandTokenSet: Set<String> = []
    private let maxCommandTokensStored = 20
    private var bufferedSamplePayloads: [[String: Any]] = []
    private var pendingUserInfoTransfers: [WCSessionUserInfoTransfer] = []
    private var offlineSampleBuffer: [[String: Any]] = []
    private var lastOfflineFlushDate: Date = .distantPast
    private let offlineBatchSize = 25
    private let offlineFlushInterval: TimeInterval = 15
    private let catchupBatchLimit = 180

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            Task { sendCurrentState() }
        }
    }

    func sendCurrentState() {
        let state: ConnectionState = WorkoutManager.shared.isTracking ? .tracking : .ready
        sendConnectionState(state)
    }

    func sendSnapshot(sample: WatchSleepSample) {
        var payload = basePayload(for: sample)
        payload["timestamp"] = Date().timeIntervalSince1970
        payload["connected"] = true
        transmit(message: payload)
    }

    func sendLiveSample(sample: WatchSleepSample, remState: REMState) {
        let payload = encodedSamplePayload(for: sample, remState: remState)
        transmit(message: payload, allowBuffering: true)
    }

    func sendSessionEvent(_ event: SessionEvent) {
        transmit(message: event.payload)
    }

    func sendConnectionState(_ state: ConnectionState) {
        currentState = state
        var payload: [String: Any] = [
            "status": state.rawValue,
            "connected": state != .inactive
        ]
        let snapshot = currentStatusSnapshot()
        payload["tracking"] = snapshot["tracking"]
        payload["sessionId"] = snapshot["sessionId"]
        payload["start"] = snapshot["start"]
        transmit(message: payload)
    }

      func requestStatusSnapshot(completion: @escaping @MainActor (WatchStatusSnapshot) -> Void) {
          guard WCSession.isSupported() else { return }
          let session = WCSession.default
          guard session.isReachable else { return }
          session.sendMessage([
              "command": "statusRequest"
          ], replyHandler: { response in
              Task { @MainActor in
                  let tracking = (response["tracking"] as? Bool) ?? false
                  let sessionIdString = response["sessionId"] as? String
                  let sessionId = sessionIdString.flatMap { UUID(uuidString: $0) }
                  let startInterval = response["start"] as? Double ?? 0
                  let startDate = startInterval > 0 ? Date(timeIntervalSince1970: startInterval) : nil
                  completion(WatchStatusSnapshot(isTracking: tracking, sessionId: sessionId, startDate: startDate))
              }
          }, errorHandler: { _ in })
      }

    private func transmit(message: [String: Any], allowBuffering: Bool = false) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else if allowBuffering {
            bufferedSamplePayloads.append(message)
            enqueueBackgroundTransfer(for: message)
        } else {
            try? session.updateApplicationContext(message)
        }
    }

    func flushBufferedSamplesIfNeeded() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.isReachable, !bufferedSamplePayloads.isEmpty else { return }
        while !bufferedSamplePayloads.isEmpty {
            let payload = bufferedSamplePayloads.removeFirst()
            session.sendMessage(payload, replyHandler: nil)
        }
    }

    func forceFlushOfflineSamples() {
        flushOfflineBufferIfNeeded(force: true)
    }

    private func enqueueBackgroundTransfer(for payload: [String: Any]) {
        if payload["event"] as? String == "sample" {
            bufferOfflineSamplePayload(payload)
            return
        }
        sendUserInfoPayload(payload)
    }

    private func bufferOfflineSamplePayload(_ payload: [String: Any]) {
        offlineSampleBuffer.append(payload)
        trimOfflineBufferIfNeeded()
        flushOfflineBufferIfNeeded()
    }

    private func trimOfflineBufferIfNeeded() {
        let overflow = offlineSampleBuffer.count - offlineBatchSize * 20
        if overflow > 0 {
            offlineSampleBuffer.removeFirst(overflow)
        }
    }

    private func flushOfflineBufferIfNeeded(force: Bool = false) {
        guard !offlineSampleBuffer.isEmpty else { return }
        let elapsed = Date().timeIntervalSince(lastOfflineFlushDate)
        let shouldFlush = force || offlineSampleBuffer.count >= offlineBatchSize || elapsed >= offlineFlushInterval
        guard shouldFlush else { return }
        let samples = offlineSampleBuffer
        offlineSampleBuffer = []
        let payload: [String: Any] = [
            "event": "sampleBatch",
            "samples": samples
        ]
        let delivered = deliverBatchPayload(payload)
        if !delivered {
            offlineSampleBuffer.insert(contentsOf: samples, at: 0)
            return
        }
        lastOfflineFlushDate = Date()
    }

    @discardableResult
    private func deliverBatchPayload(_ payload: [String: Any]) -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        var delivered = false
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
            delivered = true
        }
        if session.activationState == .activated {
            let transfer = session.transferUserInfo(payload)
            pendingUserInfoTransfers.append(transfer)
            delivered = true
        }
        return delivered
    }

    private func sendUserInfoPayload(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let transfer = session.transferUserInfo(payload)
        pendingUserInfoTransfers.append(transfer)
    }

    private func handleSamplesRequest(_ payload: [String: Any]) {
        let sinceInterval = payload["since"] as? Double ?? 0
        let sinceDate = sinceInterval > 0 ? Date(timeIntervalSince1970: sinceInterval) : nil
        let requested = WorkoutManager.shared.recentSamples(after: sinceDate, limit: catchupBatchLimit)
        guard !requested.isEmpty else { return }
        let encoded = requested.map { sample, stage in
            encodedSamplePayload(for: sample, remState: stage)
        }
        let batchPayload: [String: Any] = [
            "event": "sampleBatch",
            "samples": encoded,
            "fromRequest": true
        ]
        transmit(message: batchPayload, allowBuffering: true)
    }

        private func basePayload(for sample: WatchSleepSample) -> [String: Any] {
            [
                "heartRate": sample.heartRate,
                "hrv": sample.hrv,
                "spo2": sample.spo2,
                "respiratoryRate": sample.respiratoryRate,
                "ecgConfidence": sample.ecgConfidence,
                "hypertensionRisk": sample.hypertensionRisk,
                "temperatureDelta": sample.temperatureDelta,
                "sleepScore": sample.sleepScore,
                "noiseExposure": sample.noiseExposure,
                "apneaRisk": sample.apneaRisk,
                "movement": sample.movement
            ]
        }

        private func encodedSamplePayload(for sample: WatchSleepSample, remState: REMState?) -> [String: Any] {
            var payload = basePayload(for: sample)
            payload["event"] = "sample"
            payload["timestamp"] = sample.timestamp.timeIntervalSince1970
            if let remState {
                payload["remState"] = remState.rawValue
            }
            return payload
        }
}

struct WatchStatusSnapshot {
    let isTracking: Bool
    let sessionId: UUID?
    let startDate: Date?
}

extension WatchSideConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        routeIncomingCommand(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        routeIncomingCommand(message, replyHandler: replyHandler)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        routeIncomingCommand(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        routeIncomingCommand(userInfo)
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in
            if let index = pendingUserInfoTransfers.firstIndex(where: { $0 === userInfoTransfer }) {
                pendingUserInfoTransfers.remove(at: index)
            }
            if let error {
                let retryPayload = userInfoTransfer.userInfo
                print("UserInfo transfer failed: \(error.localizedDescription)")
                if retryPayload["event"] as? String == "sampleBatch",
                   let samples = retryPayload["samples"] as? [[String: Any]] {
                    offlineSampleBuffer.insert(contentsOf: samples, at: 0)
                    trimOfflineBufferIfNeeded()
                } else {
                    bufferedSamplePayloads.append(retryPayload)
                }
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            if session.isReachable {
                self.flushBufferedSamplesIfNeeded()
            }
            self.flushOfflineBufferIfNeeded(force: session.isReachable)
        }
    }

    private nonisolated func routeIncomingCommand(_ payload: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        Task { @MainActor in
            if payload["controlStateSync"] as? Bool == true {
                reconcilePhoneControlState(payload)
                replyHandler?([:])
                return
            }

            guard let command = payload["command"] as? String else { return }
            guard shouldProcessCommand(payload) else { return }
            lastCommand = command
            if command == "ping" {
                sendConnectionState(currentState == .inactive ? .ready : currentState)
                replyHandler?(currentStatusSnapshot())
                return
            }

            if command == "watchStatusProbe" {
                replyHandler?(currentStatusSnapshot())
                return
            }

            if command == "samplesRequest" {
                handleSamplesRequest(payload)
                replyHandler?([:])
                return
            }

            if let delegate = ExtensionDelegate.shared {
                delegate.handleRemoteCommandPayload(payload)
                replyHandler?(currentStatusSnapshot())
                return
            }

            if let remoteCommand = RemoteCommand(payload: payload) {
                RemoteCommandStore.shared.enqueue(remoteCommand)
                scheduleBackgroundWake()
            }
        }
    }

    @MainActor
    private func reconcilePhoneControlState(_ payload: [String: Any]) {
        let shouldTrack = payload["tracking"] as? Bool ?? false
        if shouldTrack {
            guard let idString = payload["sessionId"] as? String,
                  let sessionId = UUID(uuidString: idString),
                  let startInterval = payload["start"] as? Double,
                  startInterval > 0 else {
                return
            }
            let startDate = Date(timeIntervalSince1970: startInterval)
            if WorkoutManager.shared.activeSessionId == sessionId {
                sendConnectionState(.tracking)
                return
            }
            if WorkoutManager.shared.isTracking {
                WorkoutManager.shared.handleRemoteStopSync()
            }
            WorkoutManager.shared.resumeIfNeeded(sessionId: sessionId, startDate: startDate)
            sendConnectionState(.tracking)
            return
        }

        if WorkoutManager.shared.isTracking {
            WorkoutManager.shared.handleRemoteStopSync()
        }
        sendConnectionState(.ready)
    }

    private func shouldProcessCommand(_ payload: [String: Any]) -> Bool {
        guard let token = payload["commandToken"] as? String else { return true }
        if processedCommandTokenSet.contains(token) {
            return false
        }
        processedCommandTokens.append(token)
        processedCommandTokenSet.insert(token)
        if processedCommandTokens.count > maxCommandTokensStored,
           let removed = processedCommandTokens.first {
            processedCommandTokens.removeFirst()
            processedCommandTokenSet.remove(removed)
        }
        return true
    }

    @MainActor
    private func scheduleBackgroundWake() {
        let preferredDate = Date().addingTimeInterval(5)
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: preferredDate, userInfo: nil) { error in
            if let error {
                print("Failed to schedule background wake: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func currentStatusSnapshot() -> [String: Any] {
        let workout = WorkoutManager.shared
        var payload: [String: Any] = [
            "tracking": workout.isTracking,
            "connected": currentState != .inactive
        ]
        if workout.isTracking {
            if let sessionId = workout.activeSessionId {
                payload["sessionId"] = sessionId.uuidString
            }
            if let start = workout.sessionStartDate?.timeIntervalSince1970 {
                payload["start"] = start
            }
        }
        return payload
    }
}

enum SessionEvent {
    case started(id: UUID, start: Date)
    case ended(id: UUID, start: Date, end: Date, samples: [StagedSample])

    struct StagedSample {
        let sample: WatchSleepSample
        let stage: REMState
    }

    var payload: [String: Any] {
        switch self {
        case let .started(id, start):
            return [
                "event": "sleepStart",
                "sessionId": id.uuidString,
                "start": start.timeIntervalSince1970
            ]
        case let .ended(id, start, end, samples):
            let encodedSamples: [[String: Any]] = samples.prefix(1000).map { staged in
                let sample = staged.sample
                return [
                    "timestamp": sample.timestamp.timeIntervalSince1970,
                    "heartRate": sample.heartRate,
                    "hrv": sample.hrv,
                    "spo2": sample.spo2,
                    "respiratoryRate": sample.respiratoryRate,
                    "ecgConfidence": sample.ecgConfidence,
                    "hypertensionRisk": sample.hypertensionRisk,
                    "temperatureDelta": sample.temperatureDelta,
                    "sleepScore": sample.sleepScore,
                    "noiseExposure": sample.noiseExposure,
                    "apneaRisk": sample.apneaRisk,
                    "movement": sample.movement,
                    "remState": staged.stage.rawValue
                ]
            }
            return [
                "event": "sleepEnd",
                "sessionId": id.uuidString,
                "start": start.timeIntervalSince1970,
                "end": end.timeIntervalSince1970,
                "samples": encodedSamples
            ]
        }
    }
}
