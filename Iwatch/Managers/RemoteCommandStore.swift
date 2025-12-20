import Foundation

struct RemoteCommand: Codable {
    let command: String
    let sessionId: UUID?
    let timestamp: Date

    init(command: String, sessionId: UUID?, timestamp: Date = Date()) {
        self.command = command
        self.sessionId = sessionId
        self.timestamp = timestamp
    }

    init?(payload: [String: Any]) {
        guard let command = payload["command"] as? String else { return nil }
        self.command = command
        if let sessionIdString = payload["sessionId"] as? String {
            self.sessionId = UUID(uuidString: sessionIdString)
        } else {
            self.sessionId = nil
        }
        if let rawTimestamp = payload["timestamp"] as? TimeInterval {
            self.timestamp = Date(timeIntervalSince1970: rawTimestamp)
        } else {
            self.timestamp = Date()
        }
    }
}

@MainActor
final class RemoteCommandStore {
    static let shared = RemoteCommandStore()

    private let storageKey = "dw.watch.pendingRemoteCommands"
    private var queue: [RemoteCommand] = []

    private init() {
        loadFromDisk()
    }

    func enqueue(_ command: RemoteCommand) {
        queue.append(command)
        persist()
    }

    func popNext() -> RemoteCommand? {
        guard !queue.isEmpty else { return nil }
        let command = queue.removeFirst()
        persist()
        return command
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([RemoteCommand].self, from: data) {
            queue = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
