import Foundation

struct BiosignalDataPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let heartRate: Double
    let hrv: Double
    let movement: Double
    let spo2: Double
    let respiratoryRate: Double
    let ecgConfidence: Double
    let hypertensionRisk: Double
    let wristTemperatureDelta: Double
    let sleepScore: Double
    let noiseExposure: Double
    let apneaRisk: Double
    /// Stage assigned by the watch classifier. Nil for samples recorded before
    /// staging was transported, or for locally simulated sessions.
    let sleepStage: REMState?

    init(id: UUID = UUID(),
         timestamp: Date,
         heartRate: Double,
         hrv: Double,
         movement: Double = 0,
         spo2: Double = 0,
         respiratoryRate: Double = 0,
         ecgConfidence: Double = 0,
         hypertensionRisk: Double = 0,
         wristTemperatureDelta: Double = 0,
         sleepScore: Double = 0,
         noiseExposure: Double = 0,
         apneaRisk: Double = 0,
         sleepStage: REMState? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
        self.movement = movement
        self.spo2 = spo2
        self.respiratoryRate = respiratoryRate
        self.ecgConfidence = ecgConfidence
        self.hypertensionRisk = hypertensionRisk
        self.wristTemperatureDelta = wristTemperatureDelta
        self.sleepScore = sleepScore
        self.noiseExposure = noiseExposure
        self.apneaRisk = apneaRisk
        self.sleepStage = sleepStage
    }
}
