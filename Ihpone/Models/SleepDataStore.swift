import Foundation
import Combine

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
}

struct SleepSession {
    let id = UUID()
    let startedAt: Date = Date()
    var endedAt: Date?
    var biosignals: [BiosignalDataPoint] = []
    var averageHeartRate: Double = 60
    var hrvAverage: Double = 52
    var ambientNoiseAvg: Double = 0.2

    mutating func finish() {
        endedAt = Date()
    }
}
