import Foundation
import HealthKit

final class HealthKitManager {
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let readTypes: Set = [HKObjectType.quantityType(forIdentifier: .heartRate)!,
                              HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!]
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }
}
