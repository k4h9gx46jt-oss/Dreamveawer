import Foundation
import HealthKit
import Combine

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    @Published var isTracking = false
    @Published var currentHeartRate: Double = 0
    @Published var currentHRV: Double = 0
    @Published var elapsed: TimeInterval = 0

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var pushTimer: Timer?
    private let pushInterval: TimeInterval = 5

    func start() {
        Task { try? await requestAuthorization() }
        configureWorkout()
        isTracking = true
        elapsed = 0
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
        workoutSession?.end()
        builder?.endCollection(withEnd: Date(), completion: { _, _ in })
        workoutSession = nil
        builder = nil
        timer?.invalidate()
        timer = nil
        pushTimer?.invalidate()
        pushTimer = nil
        isTracking = false
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
        }
    }
}
