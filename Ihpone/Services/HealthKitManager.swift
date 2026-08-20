import Foundation
import HealthKit

final class HealthKitManager {
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// The signals DreamWeaver surfaces from a night — requested together so the
    /// Health sheet is shown once.
    private var readTypes: Set<HKObjectType> {
        let quantities: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .respiratoryRate,
            .environmentalAudioExposure
        ]
        var types = Set<HKObjectType>(quantities.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { return }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Whether the Health permission sheet still needs to be shown. HealthKit
    /// deliberately hides read-grant status, so this is the only reliable signal.
    func requestStatus() async -> HKAuthorizationRequestStatus {
        guard isHealthDataAvailable else { return .unknown }
        return await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                continuation.resume(returning: status)
            }
        }
    }
}
