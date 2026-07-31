import Foundation
import Testing
@testable import DreamWeaver

/// Deterministic dream fixtures so tests never depend on the randomised mock generator.
enum DreamFixture {
    /// Builds a dream whose REM profile is fully specified, for a given mood and intensity.
    static func dream(mood: DreamMood,
                      intensity: Double = 0.45,
                      polarity: Double = 0.4,
                      apneaSpikes: Int = 1,
                      noiseSpikes: Int = 0,
                      segmentCount: Int = 3,
                      totalDuration: TimeInterval = 1800,
                      startedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> SleepData {
        let end = startedAt.addingTimeInterval(4 * 3600)
        let segments = (0..<segmentCount).map { index -> REMSegment in
            let offset = TimeInterval(index) * 600 + 300
            return REMSegment(
                start: startedAt.addingTimeInterval(offset),
                end: startedAt.addingTimeInterval(offset + 300),
                dominantDriver: [.heartRate, .hrv, .apnea, .noise, .temperature, .unknown][index % 6],
                heartRateAvg: 56 + Double(index) * 6,
                hrvAvg: 62 - Double(index) * 4,
                intensity: intensity,
                moodPolarity: polarity
            )
        }

        return SleepData(
            startedAt: startedAt,
            endedAt: end,
            averageHeartRate: 60,
            remPercentage: 26,
            deepSleepPercentage: 30,
            hrvAverage: 58,
            mood: mood,
            aiNarrative: "Test narrative",
            aiThemes: ["cosmos", "memory"],
            aiSymbolism: ["⭐", "🌊"],
            aiIntensity: intensity,
            aiConsciousness: 0.3,
            aiVisualPrompt: "Test prompt",
            biosignals: biosignals(from: startedAt, count: 40),
            ambientNoiseLevel: 0.2,
            remProfile: REMDreamProfile(
                totalDuration: totalDuration,
                intensityScore: intensity,
                moodPolarity: polarity,
                heartRateTrend: .rising,
                hrvTrend: .falling,
                apneaSpikeCount: apneaSpikes,
                noiseSpikeCount: noiseSpikes,
                segments: segments
            )
        )
    }

    /// Smooth, movement-free samples so REM segmentation always finds windows.
    static func biosignals(from start: Date,
                           count: Int,
                           spacing: TimeInterval = 60,
                           movement: Double = 0.1,
                           heartRate: Double = 62,
                           apneaRisk: Double = 0.1,
                           noiseExposure: Double = 32) -> [BiosignalDataPoint] {
        (0..<count).map { index in
            BiosignalDataPoint(
                timestamp: start.addingTimeInterval(TimeInterval(index) * spacing),
                heartRate: heartRate + sin(Double(index) / 5) * 3,
                hrv: 55 + cos(Double(index) / 4) * 6,
                movement: movement,
                spo2: 96,
                respiratoryRate: 14,
                ecgConfidence: 0.9,
                hypertensionRisk: 0.1,
                wristTemperatureDelta: 0.2,
                sleepScore: 85,
                noiseExposure: noiseExposure,
                apneaRisk: apneaRisk
            )
        }
    }

    static func prompt(for dream: SleepData) throws -> DreamMediaPrompt {
        let profile = try #require(dream.remProfile)
        return DreamMediaPrompt(dream: dream, profile: profile)
    }

    static func scoreProfile(for dream: SleepData) throws -> DreamScoreProfile {
        DreamScoreProfile(dream: dream, prompt: try prompt(for: dream))
    }

    static func visualProfile(for dream: SleepData) throws -> DreamVisualProfile {
        let prompt = try prompt(for: dream)
        return DreamVisualProfile(mood: dream.mood,
                                  genre: prompt.genre,
                                  profile: try #require(dream.remProfile),
                                  seed: makeSeed(from: dream.id))
    }

    /// A scratch directory that the caller is responsible for removing.
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DreamWeaverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
