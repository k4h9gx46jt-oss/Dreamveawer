import Foundation
import SwiftUI

struct SleepData: Identifiable, Codable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
    var averageHeartRate: Double
    var remPercentage: Double
    var deepSleepPercentage: Double
    var hrvAverage: Double
    var mood: DreamMood
    var aiNarrative: String
    var aiThemes: [String]
    var aiSymbolism: [String]
    var aiIntensity: Double
    var aiConsciousness: Double
    var aiVisualPrompt: String
    var biosignals: [BiosignalDataPoint]
    var ambientNoiseLevel: Double

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        averageHeartRate: Double,
        remPercentage: Double,
        deepSleepPercentage: Double,
        hrvAverage: Double,
        mood: DreamMood,
        aiNarrative: String,
        aiThemes: [String],
        aiSymbolism: [String],
        aiIntensity: Double,
        aiConsciousness: Double,
        aiVisualPrompt: String,
        biosignals: [BiosignalDataPoint],
        ambientNoiseLevel: Double
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.averageHeartRate = averageHeartRate
        self.remPercentage = remPercentage
        self.deepSleepPercentage = deepSleepPercentage
        self.hrvAverage = hrvAverage
        self.mood = mood
        self.aiNarrative = aiNarrative
        self.aiThemes = aiThemes
        self.aiSymbolism = aiSymbolism
        self.aiIntensity = aiIntensity
        self.aiConsciousness = aiConsciousness
        self.aiVisualPrompt = aiVisualPrompt
        self.biosignals = biosignals
        self.ambientNoiseLevel = ambientNoiseLevel
    }
}

extension SleepData {
    static func mock(durationHours: Double = 3.8) -> SleepData {
        let end = Date()
        let start = end.addingTimeInterval(-(durationHours * 3600))
        let biosignals = stride(from: 0.0, through: durationHours * 3600, by: 300).map { offset -> BiosignalDataPoint in
            let base = 60.0 + sin(offset / 600) * 6.0
            let hrv = 50.0 + cos(offset / 540) * 10.0
            let movement = Double.random(in: 0...1)
            return BiosignalDataPoint(
                timestamp: start.addingTimeInterval(offset),
                heartRate: base + Double.random(in: -4...4),
                hrv: hrv + Double.random(in: -5...5),
                movement: movement
            )
        }

        return SleepData(
            startedAt: start,
            endedAt: end,
            averageHeartRate: 58,
            remPercentage: 28,
            deepSleepPercentage: 31,
            hrvAverage: 65,
            mood: .peaceful,
            aiNarrative: "Vast cosmic tides glow in rhythm with your breathing. You float between pale auroras, weaving constellations with the pulse of your heart.",
            aiThemes: ["cosmos", "transformation", "serenity"],
            aiSymbolism: ["⭐", "🌊", "🌀"],
            aiIntensity: 0.42,
            aiConsciousness: 0.18,
            aiVisualPrompt: "Ethereal nebula softly rippling over calm water, translucent particles orbiting a glowing orb",
            biosignals: biosignals,
            ambientNoiseLevel: 0.12
        )
    }
}
