import Foundation
import HealthKit
import Combine

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    @Published var isTracking = false
    @Published var currentHeartRate: Double = 0
    @Published var currentHRV: Double = 0
    @Published var elapsed: TimeInterval = 0
    @Published private(set) var samples: [WatchSleepSample] = []
    @Published private(set) var remWindows: [REMWindow] = []

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var pushTimer: Timer?
    private let pushInterval: TimeInterval = 5
    private var sessionId = UUID()
    private var sessionStartDate: Date?
    private var currentREMState: REMState = .light

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleCommand(_:)), name: .watchCommand, object: nil)
    }

    func start() {
        guard !isTracking else { return }
        Task { try? await requestAuthorization() }
        configureWorkout()
        isTracking = true
        elapsed = 0
        sessionId = UUID()
        sessionStartDate = Date()
        samples.removeAll()
        remWindows.removeAll()
        currentREMState = .light
        WatchSideConnectivityManager.shared.sendSessionEvent(.started(id: sessionId, start: sessionStartDate ?? Date()))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed += 1 }
        }
        Task { @MainActor in
            WatchSideConnectivityManager.shared.sendConnectionState(.tracking)
            WatchSideConnectivityManager.shared.sendSnapshot(
                heartRate: self.currentHeartRate,
                hrv: self.currentHRV
            )
        }
        pushTimer = Timer.scheduledTimer(withTimeInterval: pushInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                WatchSideConnectivityManager.shared.sendSnapshot(
                    heartRate: self.currentHeartRate,
                    hrv: self.currentHRV
                )
            }
        }
    }

    func stop() {
        guard isTracking else { return }
        workoutSession?.end()
        builder?.endCollection(withEnd: Date(), completion: { _, _ in })
        workoutSession = nil
        builder = nil
        timer?.invalidate()
        timer = nil
        pushTimer?.invalidate()
        pushTimer = nil
        isTracking = false
        let endDate = Date()
        WatchSideConnectivityManager.shared.sendSessionEvent(.ended(id: sessionId, start: sessionStartDate ?? endDate, end: endDate, samples: samples))
        Task { @MainActor in
            WatchSideConnectivityManager.shared.sendConnectionState(.ready)
        }
    }

    private func configureWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            workoutSession?.delegate = self
            builder?.delegate = self
            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            print("Failed to start workout: \(error.localizedDescription)")
        }
    }

    private func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToRead: Set = [HKObjectType.quantityType(forIdentifier: .heartRate)!,
                                HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!]
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        else { return }

        Task { @MainActor in
            if collectedTypes.contains(hrType),
               let statistics = workoutBuilder.statistics(for: hrType),
               let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) {
                currentHeartRate = value
            }
            if collectedTypes.contains(hrvType),
               let statistics = workoutBuilder.statistics(for: hrvType),
               let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli)) {
                currentHRV = value
            }
            recordSample()
        }
    }
}

private extension WorkoutManager {
    func recordSample() {
        guard isTracking else { return }
        let sample = WatchSleepSample(timestamp: Date(), heartRate: currentHeartRate, hrv: currentHRV)
        samples.append(sample)
        if samples.count > 720 { samples.removeFirst() }
        updateREM(using: sample)
        WatchSideConnectivityManager.shared.sendLiveSample(sample: sample, remState: currentREMState)
    }

    func updateREM(using sample: WatchSleepSample) {
        let lowHRV = sample.hrv < 35
        if sample.heartRate >= 50 && sample.heartRate <= 75 && !lowHRV {
            if currentREMState != .rem {
                let window = REMWindow(start: sample.timestamp, end: sample.timestamp.addingTimeInterval(60))
                remWindows.append(window)
            } else if var last = remWindows.popLast() {
                last = last.extended(to: sample.timestamp)
                remWindows.append(last)
            }
            currentREMState = .rem
        } else if sample.heartRate < 50 {
            currentREMState = .deep
        } else {
            currentREMState = .light
        }
    }

    @objc func handleCommand(_ notification: Notification) {
        guard let command = notification.userInfo?["command"] as? String else { return }
        switch command {
        case "startSleep":
            start()
        case "stopSleep":
            stop()
        default:
            break
        }
    }
}

struct WatchSleepSample: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let heartRate: Double
    let hrv: Double

    init(id: UUID = UUID(), timestamp: Date, heartRate: Double, hrv: Double) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
    }
}

struct REMWindow: Identifiable, Codable {
    let id: UUID
    let start: Date
    let end: Date

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }

    func extended(to date: Date) -> REMWindow {
        REMWindow(id: id, start: start, end: date)
    }
}

enum REMState: String, Codable {
    case light
    case deep
    case rem
}
