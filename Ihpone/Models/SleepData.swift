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
    var remProfile: REMDreamProfile?

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
        ambientNoiseLevel: Double,
        remProfile: REMDreamProfile? = nil
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
        self.remProfile = remProfile
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
                movement: movement,
                spo2: 96 + Double.random(in: -2...1),
                respiratoryRate: 14 + Double.random(in: -2...2),
                ecgConfidence: Double.random(in: 0.8...0.98),
                hypertensionRisk: Double.random(in: 0.05...0.25),
                wristTemperatureDelta: Double.random(in: -0.4...0.6),
                sleepScore: Double.random(in: 78...92),
                noiseExposure: Double.random(in: 28...48),
                apneaRisk: Double.random(in: 0.04...0.2)
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
            ambientNoiseLevel: 0.12,
            remProfile: REMDreamProfile(
                totalDuration: 1800,
                intensityScore: 0.4,
                moodPolarity: 0.6,
                heartRateTrend: .rising,
                hrvTrend: .falling,
                apneaSpikeCount: 1,
                noiseSpikeCount: 0,
                segments: [
                    REMSegment(
                        start: start.addingTimeInterval(600),
                        end: start.addingTimeInterval(900),
                        dominantDriver: .heartRate,
                        heartRateAvg: 64,
                        hrvAvg: 58,
                        intensity: 0.45,
                        moodPolarity: 0.7
                    ),
                    REMSegment(
                        start: start.addingTimeInterval(1200),
                        end: start.addingTimeInterval(1500),
                        dominantDriver: .hrv,
                        heartRateAvg: 60,
                        hrvAvg: 62,
                        intensity: 0.38,
                        moodPolarity: 0.65
                    )
                ]
            )
        )
    }
}

struct REMDreamProfile: Codable {
    let totalDuration: TimeInterval
    let intensityScore: Double
    let moodPolarity: Double
    let heartRateTrend: REMTrend
    let hrvTrend: REMTrend
    let apneaSpikeCount: Int
    let noiseSpikeCount: Int
    let segments: [REMSegment]
}

struct REMSegment: Identifiable, Codable {
    let id: UUID
    let start: Date
    let end: Date
    let dominantDriver: REMDriver
    let heartRateAvg: Double
    let hrvAvg: Double
    let intensity: Double
    let moodPolarity: Double

    init(id: UUID = UUID(),
         start: Date,
         end: Date,
         dominantDriver: REMDriver,
         heartRateAvg: Double,
         hrvAvg: Double,
         intensity: Double,
         moodPolarity: Double) {
        self.id = id
        self.start = start
        self.end = end
        self.dominantDriver = dominantDriver
        self.heartRateAvg = heartRateAvg
        self.hrvAvg = hrvAvg
        self.intensity = intensity
        self.moodPolarity = moodPolarity
    }
}

enum REMDriver: String, Codable {
    case heartRate
    case hrv
    case apnea
    case noise
    case temperature
    case unknown
}

enum REMTrend: String, Codable {
    case rising
    case falling
    case stable
}

extension REMTrend {
    static func from(first: Double, last: Double, threshold: Double = 1.5) -> REMTrend {
        let delta = last - first
        if delta > threshold { return .rising }
        if delta < -threshold { return .falling }
        return .stable
    }
}
