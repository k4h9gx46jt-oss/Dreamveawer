import WatchKit

final class ExtensionDelegate: NSObject, WKExtensionDelegate {
    static private(set) var shared: ExtensionDelegate?

    override init() {
        super.init()
        _ = WatchSideConnectivityManager.shared
        ExtensionDelegate.shared = self
    }

    func applicationDidFinishLaunching() {
        Task { @MainActor in
            WatchSideConnectivityManager.shared.sendConnectionState(.ready)
            processPendingCommands()
        }
    }

    func applicationDidBecomeActive() {
        Task { @MainActor in
            WatchSideConnectivityManager.shared.sendConnectionState(.ready)
            processPendingCommands()
        }
    }

    func applicationWillResignActive() {
        Task { @MainActor in
            WatchSideConnectivityManager.shared.sendConnectionState(.inactive)
        }
    }

    @MainActor
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let wcTask as WKWatchConnectivityRefreshBackgroundTask:
                processPendingCommands()
                let connectionState: WatchSideConnectivityManager.ConnectionState = WorkoutManager.shared.isTracking ? .tracking : .ready
                WatchSideConnectivityManager.shared.sendConnectionState(connectionState)
                wcTask.setTaskCompletedWithSnapshot(false)
            case let appTask as WKApplicationRefreshBackgroundTask:
                appTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: .distantFuture, userInfo: nil)
            case let urlTask as WKURLSessionRefreshBackgroundTask:
                urlTask.setTaskCompletedWithSnapshot(false)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    @MainActor
    func handleRemoteCommandPayload(_ payload: [String: Any]) {
        guard let command = RemoteCommand(payload: payload) else { return }
        RemoteCommandStore.shared.enqueue(command)
        processPendingCommands()
    }

    @MainActor
    private func processPendingCommands() {
        var didProcess = false
        while let command = RemoteCommandStore.shared.popNext() {
            didProcess = true
            execute(command)
        }
        if didProcess {
            let state: WatchSideConnectivityManager.ConnectionState = WorkoutManager.shared.isTracking ? .tracking : .ready
            WatchSideConnectivityManager.shared.sendConnectionState(state)
        }
    }

    @MainActor
    private func execute(_ command: RemoteCommand) {
        switch command.command {
        case "startSleep":
            WorkoutManager.shared.start(remoteSessionId: command.sessionId)
        case "stopSleep":
            WorkoutManager.shared.stop()
        default:
            break
        }
    }
}
