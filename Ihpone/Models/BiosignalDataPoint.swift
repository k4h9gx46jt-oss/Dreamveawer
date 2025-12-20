import Foundation

struct BiosignalDataPoint: Identifiable, Codable {
    let id: UUID = UUID()
    let timestamp: Date
    let heartRate: Double
    let hrv: Double
    let movement: Double
}
