import Foundation
import Combine

struct RemoteSleepSessionResult {
    let sessionId: UUID?
    let startedAt: Date
    let endedAt: Date
    let samples: [BiosignalDataPoint]
}

@MainActor
final class SleepDataStore: ObservableObject {
    @Published private(set) var dreams: [SleepData] = [SleepData.mock(), SleepData.mock(durationHours: 2.3)]
    @Published var activeSession: SleepSession?

    func startNewSession() {
        guard activeSession == nil else { return }
        activeSession = SleepSession()
    }

    @discardableResult
    func addDream(from session: SleepSession, aiResult: SleepAIResult) -> SleepData {
        let dream = SleepData(
            startedAt: session.startedAt,
            endedAt: session.endedAt ?? Date(),
            averageHeartRate: session.averageHeartRate,
            remPercentage: aiResult.remEstimate,
            deepSleepPercentage: aiResult.deepSleepEstimate,
            hrvAverage: session.hrvAverage,
            mood: aiResult.mood,
            aiNarrative: aiResult.narrative,
            aiThemes: aiResult.themes,
            aiSymbolism: aiResult.symbolism,
            aiIntensity: aiResult.intensity,
            aiConsciousness: aiResult.consciousness,
            aiVisualPrompt: aiResult.visualPrompt,
            biosignals: session.biosignals,
            ambientNoiseLevel: session.ambientNoiseAvg,
            remProfile: session.remProfile
        )

        dreams.insert(dream, at: 0)
        activeSession = nil
        return dream
    }

    func ingestRemoteSession(_ result: RemoteSleepSessionResult) async {
        var session = SleepSession(startedAt: result.startedAt, biosignals: result.samples)
        session.finish(on: result.endedAt)
        session.recalculateAverages()
        session.analyzeREMProfile()
        _ = await persistSession(session)
    }

    @discardableResult
    func persistSession(_ session: SleepSession) async -> SleepData? {
        var enrichedSession = session
        if enrichedSession.remProfile == nil {
            enrichedSession.analyzeREMProfile()
        }
        let aiResult = await Task.detached(priority: .userInitiated) {
            try? await AIDreamService.shared.interpret(session: enrichedSession)
        }.value

        guard let aiResult else {
            print("AI interpretation failed")
            return nil
        }

        return addDream(from: enrichedSession, aiResult: aiResult)
    }
}

struct SleepSession {
    let id = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var biosignals: [BiosignalDataPoint] = []
    var averageHeartRate: Double = 60
    var hrvAverage: Double = 52
    var ambientNoiseAvg: Double = 0.2
    var remProfile: REMDreamProfile?

    mutating func finish(on date: Date = Date()) {
        endedAt = date
    }

    mutating func recalculateAverages() {
        guard !biosignals.isEmpty else { return }
        averageHeartRate = biosignals.map { $0.heartRate }.average()
        hrvAverage = biosignals.map { $0.hrv }.average()
        ambientNoiseAvg = biosignals.map { $0.noiseExposure }.average()
    }

    mutating func analyzeREMProfile() {
        guard !biosignals.isEmpty else {
            remProfile = nil
            return
        }
        remProfile = REMDreamProfile.build(from: biosignals,
                                           defaultStart: startedAt,
                                           defaultEnd: endedAt ?? Date())
    }
}

private extension REMDreamProfile {
    static func build(from samples: [BiosignalDataPoint], defaultStart: Date, defaultEnd: Date) -> REMDreamProfile? {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        guard let firstTimestamp = ordered.first?.timestamp else { return nil }
        var segments: [REMSegment] = []
        var bucket: [BiosignalDataPoint] = []
        var bucketStart = firstTimestamp
        let window: TimeInterval = 60

        func flush(until endDate: Date) {
            defer {
                bucket = []
            }
            guard !bucket.isEmpty else { return }
            guard let segment = Self.makeSegment(from: bucket, start: bucketStart, end: endDate) else { return }
            segments.append(segment)
        }

        for sample in ordered {
            if sample.timestamp.timeIntervalSince(bucketStart) >= window {
                flush(until: sample.timestamp)
                bucketStart = sample.timestamp
            }
            bucket.append(sample)
        }
        if let last = bucket.last?.timestamp {
            flush(until: last)
        }

        guard !segments.isEmpty else { return nil }

        let totalDuration = segments.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        let intensityScore = segments.map { $0.intensity }.average()
        let moodPolarity = segments.map { $0.moodPolarity }.average()
        let apneaSpikeCount = segments.filter { $0.dominantDriver == .apnea }.count
        let noiseSpikeCount = segments.filter { $0.dominantDriver == .noise }.count
        let heartRateTrend = REMTrend.from(first: segments.first?.heartRateAvg ?? 0,
                                           last: segments.last?.heartRateAvg ?? 0)
        let hrvTrend = REMTrend.from(first: segments.first?.hrvAvg ?? 0,
                                     last: segments.last?.hrvAvg ?? 0)

        return REMDreamProfile(
            totalDuration: totalDuration == 0 ? defaultEnd.timeIntervalSince(defaultStart) : totalDuration,
            intensityScore: intensityScore,
            moodPolarity: moodPolarity,
            heartRateTrend: heartRateTrend,
            hrvTrend: hrvTrend,
            apneaSpikeCount: apneaSpikeCount,
            noiseSpikeCount: noiseSpikeCount,
            segments: segments
        )
    }

    static func makeSegment(from samples: [BiosignalDataPoint], start: Date, end: Date) -> REMSegment? {
        guard !samples.isEmpty else { return nil }
        let movementAvg = samples.map { $0.movement }.average()
        guard movementAvg <= 0.45 else { return nil }

        let heartAvg = samples.map { $0.heartRate }.average()
        let hrvAvg = samples.map { $0.hrv }.average()
        let apneaMax = samples.map { $0.apneaRisk }.max() ?? 0
        let noiseAvg = samples.map { $0.noiseExposure }.average()
        let tempDrift = samples.map { $0.wristTemperatureDelta }.average()

        let hrDeviation = abs(heartAvg - 60) / 40
        let intensity = clamp(hrDeviation + apneaMax * 0.5 + abs(tempDrift) * 0.1, low: 0, high: 1)
        let moodPolarity = clamp((hrvAvg - 40) / 50 - (noiseAvg - 35) / 80, low: -1, high: 1)

        let driver: REMDriver
        if apneaMax > 0.65 {
            driver = .apnea
        } else if noiseAvg > 55 {
            driver = .noise
        } else if hrDeviation > 0.5 {
            driver = .heartRate
        } else if hrvAvg < 35 {
            driver = .hrv
        } else if abs(tempDrift) > 0.8 {
            driver = .temperature
        } else {
            driver = .unknown
        }

        return REMSegment(
            start: start,
            end: end,
            dominantDriver: driver,
            heartRateAvg: heartAvg,
            hrvAvg: hrvAvg,
            intensity: intensity,
            moodPolarity: moodPolarity
        )
    }
}

private func clamp(_ value: Double, low: Double, high: Double) -> Double {
    min(max(value, low), high)
}

private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        let total = reduce(0, +)
        return total / Double(count)
    }
}
