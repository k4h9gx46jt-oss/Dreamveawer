import Foundation
import HealthKit
import Combine

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()

    @Published var isTracking = false
    @Published var currentHeartRate: Double = 0
    @Published var currentHRV: Double = 0
    @Published var currentSpO2: Double = 98
    @Published var currentRespiratoryRate: Double = 14
    @Published var currentECGConfidence: Double = 0.95
    @Published var currentHypertensionRisk: Double = 0.1
    @Published var currentTemperatureDelta: Double = 0
    @Published var currentSleepScore: Double = 85
    @Published var currentNoiseExposure: Double = 30
    @Published var currentApneaRisk: Double = 0.05
    @Published var elapsed: TimeInterval = 0
    @Published private(set) var sessionStartDate: Date?
    @Published private(set) var samples: [WatchSleepSample] = []
    @Published private(set) var remWindows: [REMWindow] = []
    @Published private(set) var currentREMState: REMState = .light

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var pushTimer: Timer?
    private var scheduledSampleTimer: Timer?
    private let pushInterval: TimeInterval = 5
    private let scheduledSampleInterval: TimeInterval = 1
    private var sessionId = UUID()
    private let persistence = UserDefaults.standard

    private enum PersistenceKeys {
        static let tracking = "dw.watch.tracking"
        static let start = "dw.watch.sessionStart"
        static let sessionId = "dw.watch.sessionId"
    }

    private override init() {
        super.init()
        restorePersistedSessionIfNeeded()
    }

    var activeSessionId: UUID? {
        isTracking ? sessionId : nil
    }

    func start(remoteSessionId: UUID? = nil) {
        guard !isTracking else { return }
        Task { try? await requestAuthorization() }
        configureWorkout()
        elapsed = 0
        samples.removeAll()
        remWindows.removeAll()
        currentREMState = .light
        baselineAdvancedSignals()
        sessionId = remoteSessionId ?? UUID()
        sessionStartDate = Date()
        isTracking = true
        startElapsedTimer()
        Task { @MainActor in
            WatchSideConnectivityManager.shared.sendConnectionState(.tracking)
            WatchSideConnectivityManager.shared.sendSnapshot(sample: self.makeSnapshotSample())
        }
        startPushTimer()
        startScheduledSampleTimer()
        WatchSideConnectivityManager.shared.sendSessionEvent(.started(id: sessionId, start: sessionStartDate ?? Date()))
        persistSessionState()
    }

    func stop() {
        guard isTracking else { return }
        let endDate = Date()
        let startDate = sessionStartDate ?? endDate
        completeStop(startDate: startDate, endDate: endDate, notifyPhone: true)
    }

    func refreshElapsed(reference date: Date = Date()) {
        guard let start = sessionStartDate else {
            elapsed = 0
            return
        }
        elapsed = max(0, date.timeIntervalSince(start))
    }

    func resumeIfNeeded(sessionId: UUID, startDate: Date) {
        guard !isTracking else { return }
        resumeExistingSession(sessionId: sessionId, startDate: startDate)
    }

    func handleRemoteStopSync() {
        guard isTracking else {
            clearPersistedSession()
            return
        }
        let endDate = Date()
        let startDate = sessionStartDate ?? endDate
        completeStop(startDate: startDate, endDate: endDate, notifyPhone: false)
    }

    private func resumeExistingSession(sessionId: UUID, startDate: Date) {
        Task { try? await requestAuthorization() }
        configureWorkout()
        self.sessionId = sessionId
        sessionStartDate = startDate
        elapsed = max(0, Date().timeIntervalSince(startDate))
        samples.removeAll()
        remWindows.removeAll()
        currentREMState = .light
        baselineAdvancedSignals()
        isTracking = true
        startElapsedTimer()
        startPushTimer()
        startScheduledSampleTimer()
        persistSessionState()
        WatchSideConnectivityManager.shared.sendConnectionState(.tracking)
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
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .respiratoryRate,
            .environmentalAudioExposure
        ]
        let quantityTypes = identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) }
        guard !quantityTypes.isEmpty else { return }
        try await healthStore.requestAuthorization(toShare: [], read: Set(quantityTypes))
    }

    private func startElapsedTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await MainActor.run {
                    self?.refreshElapsed()
                }
            }
        }
    }

    private func startPushTimer() {
        pushTimer?.invalidate()
        pushTimer = Timer.scheduledTimer(withTimeInterval: pushInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                await MainActor.run {
                    WatchSideConnectivityManager.shared.sendSnapshot(sample: self.makeSnapshotSample())
                }
            }
        }
    }

    private func startScheduledSampleTimer() {
        scheduledSampleTimer?.invalidate()
        scheduledSampleTimer = Timer.scheduledTimer(withTimeInterval: scheduledSampleInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.emitScheduledSample()
            }
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        pushTimer?.invalidate()
        pushTimer = nil
        scheduledSampleTimer?.invalidate()
        scheduledSampleTimer = nil
    }

    private func completeStop(startDate: Date, endDate: Date, notifyPhone: Bool) {
        workoutSession?.end()
        builder?.endCollection(withEnd: endDate, completion: { _, _ in })
        workoutSession = nil
        builder = nil
        stopTimers()
        isTracking = false
        sessionStartDate = nil
        WatchSideConnectivityManager.shared.sendSnapshot(sample: makeSnapshotSample())
        if notifyPhone {
            WatchSideConnectivityManager.shared.sendSessionEvent(.ended(id: sessionId, start: startDate, end: endDate, samples: samples))
        }
        Task { @MainActor in
            WatchSideConnectivityManager.shared.sendConnectionState(.ready)
        }
        clearPersistedSession()
    }

    private func persistSessionState() {
        persistence.set(isTracking, forKey: PersistenceKeys.tracking)
        persistence.set(sessionStartDate?.timeIntervalSince1970, forKey: PersistenceKeys.start)
        persistence.set(sessionId.uuidString, forKey: PersistenceKeys.sessionId)
    }

    private func clearPersistedSession() {
        persistence.removeObject(forKey: PersistenceKeys.tracking)
        persistence.removeObject(forKey: PersistenceKeys.start)
        persistence.removeObject(forKey: PersistenceKeys.sessionId)
    }

    private func restorePersistedSessionIfNeeded() {
        guard persistence.bool(forKey: PersistenceKeys.tracking) else { return }
        let startInterval = persistence.double(forKey: PersistenceKeys.start)
        guard startInterval > 0,
              let rawId = persistence.string(forKey: PersistenceKeys.sessionId),
              let restoredId = UUID(uuidString: rawId) else {
            clearPersistedSession()
            return
        }
        let startDate = Date(timeIntervalSince1970: startInterval)
        resumeExistingSession(sessionId: restoredId, startDate: startDate)
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
        let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
        let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate)
        let audioType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)

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
            if let spo2Type,
               collectedTypes.contains(spo2Type),
               let statistics = workoutBuilder.statistics(for: spo2Type),
               let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.percent()) {
                currentSpO2 = value * 100
            }
            if let respiratoryType,
               collectedTypes.contains(respiratoryType),
               let statistics = workoutBuilder.statistics(for: respiratoryType),
               let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) {
                currentRespiratoryRate = value
            }
            if let audioType,
               collectedTypes.contains(audioType),
               let statistics = workoutBuilder.statistics(for: audioType),
               let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel()) {
                currentNoiseExposure = value
            }
            synthesizeAdvancedSignals()
            recordSample()
        }
    }
}

private extension WorkoutManager {
    @MainActor
    func emitScheduledSample() {
        guard isTracking else { return }
        synthesizeAdvancedSignals()
        recordSample()
    }

    func recordSample() {
        guard isTracking else { return }
        let sample = makeSnapshotSample()
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

    func makeSnapshotSample() -> WatchSleepSample {
        WatchSleepSample(
            timestamp: Date(),
            heartRate: currentHeartRate,
            hrv: currentHRV,
            spo2: currentSpO2,
            respiratoryRate: currentRespiratoryRate,
            ecgConfidence: currentECGConfidence,
            hypertensionRisk: currentHypertensionRisk,
            temperatureDelta: currentTemperatureDelta,
            sleepScore: currentSleepScore,
            noiseExposure: currentNoiseExposure,
            apneaRisk: currentApneaRisk
        )
    }

    func baselineAdvancedSignals() {
        currentSpO2 = 98
        currentRespiratoryRate = 14
        currentECGConfidence = 0.95
        currentHypertensionRisk = 0.12
        currentTemperatureDelta = 0
        currentSleepScore = 85
        currentNoiseExposure = 32
        currentApneaRisk = 0.08
    }

    func synthesizeAdvancedSignals() {
        let normalizedHeart = clamp((currentHeartRate - 45) / 55, low: 0, high: 1)
        let variabilityFactor = clamp(1 - (currentHRV / 120), low: 0, high: 1)
        currentRespiratoryRate = clamp(14 + normalizedHeart * 4 + Double.random(in: -1...1), low: 10, high: 24)
        currentSpO2 = clamp(currentSpO2 + Double.random(in: -0.6...0.6) - normalizedHeart * 0.2, low: 92, high: 100)
        currentApneaRisk = clamp((100 - currentSpO2) / 25 + variabilityFactor * 0.3 + Double.random(in: -0.05...0.05), low: 0.02, high: 0.95)
        currentECGConfidence = clamp(0.98 - variabilityFactor * 0.4 + Double.random(in: -0.04...0.02), low: 0.4, high: 0.99)
        currentHypertensionRisk = clamp(normalizedHeart * 0.7 + Double.random(in: -0.08...0.08), low: 0.02, high: 0.98)
        currentTemperatureDelta = clamp(currentTemperatureDelta + Double.random(in: -0.05...0.05), low: -1.5, high: 1.8)
        currentSleepScore = clamp(currentSleepScore + Double.random(in: -0.6...0.5) - normalizedHeart * 0.1, low: 55, high: 99)
        currentNoiseExposure = clamp(currentNoiseExposure + Double.random(in: -3...3), low: 20, high: 90)
    }

    func clamp(_ value: Double, low: Double, high: Double) -> Double {
        min(max(value, low), high)
    }

}

struct WatchSleepSample: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let heartRate: Double
    let hrv: Double
    let spo2: Double
    let respiratoryRate: Double
    let ecgConfidence: Double
    let hypertensionRisk: Double
    let temperatureDelta: Double
    let sleepScore: Double
    let noiseExposure: Double
    let apneaRisk: Double

    init(id: UUID = UUID(),
         timestamp: Date,
         heartRate: Double,
         hrv: Double,
         spo2: Double,
         respiratoryRate: Double,
         ecgConfidence: Double,
         hypertensionRisk: Double,
         temperatureDelta: Double,
         sleepScore: Double,
         noiseExposure: Double,
         apneaRisk: Double) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
        self.spo2 = spo2
        self.respiratoryRate = respiratoryRate
        self.ecgConfidence = ecgConfidence
        self.hypertensionRisk = hypertensionRisk
        self.temperatureDelta = temperatureDelta
        self.sleepScore = sleepScore
        self.noiseExposure = noiseExposure
        self.apneaRisk = apneaRisk
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
