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
    @Published private(set) var dreams: [SleepData] = []
    @Published var activeSession: SleepSession?

    private let storageURL: URL

    init() {
        storageURL = Self.defaultStorageURL
        dreams = Self.loadFromDisk(at: Self.defaultStorageURL)
    }

    // Redirects storage to a caller-supplied directory — for unit tests only.
    init(_testingStorageDirectory: URL) {
        storageURL = _testingStorageDirectory.appending(path: "dreams.json")
        dreams = Self.loadFromDisk(at: storageURL)
    }

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
        saveToDisk()
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

    func deleteDream(id: UUID) {
        dreams.removeAll { $0.id == id }
        saveToDisk()
    }

    // MARK: - Disk persistence

    private static let defaultStorageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(path: "DreamWeaver/dreams.json")
    }()

    private func saveToDisk() {
        let url = storageURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(dreams)
            try data.write(to: url, options: .atomic)
        } catch {
            print("SleepDataStore: save failed – \(error)")
        }
    }

    private static func loadFromDisk(at url: URL) -> [SleepData] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SleepData].self, from: data) else {
            return []
        }
        return decoded
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
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var biosignals: [BiosignalDataPoint]
    var averageHeartRate: Double
    var hrvAverage: Double
    var ambientNoiseAvg: Double
    var remProfile: REMDreamProfile?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        biosignals: [BiosignalDataPoint] = [],
        averageHeartRate: Double = 60,
        hrvAverage: Double = 52,
        ambientNoiseAvg: Double = 0.2,
        remProfile: REMDreamProfile? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.biosignals = biosignals
        self.averageHeartRate = averageHeartRate
        self.hrvAverage = hrvAverage
        self.ambientNoiseAvg = ambientNoiseAvg
        self.remProfile = remProfile
    }

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

extension REMDreamProfile {
    /// Movement ceiling used only when a sample carries no stage from the watch.
    static let fallbackMovementCeiling: Double = 0.45

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

        // A night with no REM at all still has to produce a profile: the media
        // pipeline treats a missing profile as a hard failure, which would leave
        // the user with a recorded night and no dream film.
        if segments.isEmpty {
            guard let fallback = Self.makeSegment(from: ordered,
                                                  start: firstTimestamp,
                                                  end: ordered.last?.timestamp ?? defaultEnd,
                                                  ignoringStage: true) else {
                return nil
            }
            segments = [fallback]
        }

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

    static func makeSegment(from samples: [BiosignalDataPoint],
                            start: Date,
                            end: Date,
                            ignoringStage: Bool = false) -> REMSegment? {
        guard !samples.isEmpty else { return nil }

        if !ignoringStage, !Self.isREM(samples) { return nil }

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

    /// Prefers the stage the watch classifier already assigned. The movement
    /// heuristic is only a fallback for samples that carry no stage.
    static func isREM(_ samples: [BiosignalDataPoint]) -> Bool {
        let staged = samples.compactMap(\.sleepStage)
        if !staged.isEmpty {
            return Double(staged.filter { $0 == .rem }.count) / Double(staged.count) >= 0.5
        }
        return samples.map { $0.movement }.average() <= fallbackMovementCeiling
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
