import Foundation
import WatchConnectivity

extension Notification.Name {
    static let watchCommand = Notification.Name("WatchConnectivityCommand")
}

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

    func sendLiveSample(sample: WatchSleepSample, remState: REMState) {
        let payload: [String: Any] = [
            "event": "sample",
            "timestamp": sample.timestamp.timeIntervalSince1970,
            "heartRate": sample.heartRate,
            "hrv": sample.hrv,
            "remState": remState.rawValue
        ]
        send(message: payload)
    }

    func sendSessionEvent(_ event: SessionEvent) {
        send(message: event.payload)
    }

    func sendConnectionState(_ state: ConnectionState) {
        currentState = state
        let payload: [String: Any] = [
            "status": state.rawValue,
            "connected": state != .inactive
        ]
        send(message: payload)
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

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        routeIncomingCommand(applicationContext)
    }

    private nonisolated func routeIncomingCommand(_ payload: [String: Any]) {
        guard let command = payload["command"] as? String else { return }
        Task { @MainActor in
            lastCommand = command
            if command == "ping" {
                sendConnectionState(currentState == .inactive ? .ready : currentState)
            } else {
                NotificationCenter.default.post(name: .watchCommand, object: nil, userInfo: ["command": command])
            }
        }
    }
}

enum SessionEvent {
    case started(id: UUID, start: Date)
    case ended(id: UUID, start: Date, end: Date, samples: [WatchSleepSample])

    var payload: [String: Any] {
        switch self {
        case let .started(id, start):
            return [
                "event": "sleepStart",
                "sessionId": id.uuidString,
                "start": start.timeIntervalSince1970
            ]
        case let .ended(id, start, end, samples):
            let encodedSamples = samples.prefix(1000).map { sample in
                [
                    "timestamp": sample.timestamp.timeIntervalSince1970,
                    "heartRate": sample.heartRate,
                    "hrv": sample.hrv
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
