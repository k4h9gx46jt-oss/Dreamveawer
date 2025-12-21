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

    func addDream(from session: SleepSession, aiResult: SleepAIResult) {
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
            ambientNoiseLevel: session.ambientNoiseAvg
        )

        dreams.insert(dream, at: 0)
        activeSession = nil
    }

    func ingestRemoteSession(_ result: RemoteSleepSessionResult) async {
        var session = SleepSession(startedAt: result.startedAt, biosignals: result.samples)
        session.finish(on: result.endedAt)
        session.recalculateAverages()
        await persistSession(session)
    }

    func persistSession(_ session: SleepSession) async {
        let aiResult = await Task.detached(priority: .userInitiated) {
            try? await AIDreamService.shared.interpret(session: session)
        }.value

        guard let aiResult else {
            print("AI interpretation failed")
            return
        }

        addDream(from: session, aiResult: aiResult)
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

    mutating func finish(on date: Date = Date()) {
        endedAt = date
    }

    mutating func recalculateAverages() {
        guard !biosignals.isEmpty else { return }
        let hrSum = biosignals.reduce(0) { $0 + $1.heartRate }
        let hrvSum = biosignals.reduce(0) { $0 + $1.hrv }
        averageHeartRate = hrSum / Double(biosignals.count)
        hrvAverage = hrvSum / Double(biosignals.count)
    }
}
