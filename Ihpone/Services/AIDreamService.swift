import Foundation
import SwiftUI

struct SleepAIResult {
    let narrative: String
    let themes: [String]
    let symbolism: [String]
    let intensity: Double
    let consciousness: Double
    let visualPrompt: String
    let mood: DreamMood
    let remEstimate: Double
    let deepSleepEstimate: Double
}

struct DreamVideoScene: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let accentColor: Color
    let duration: TimeInterval
}

struct DreamVideoResult: Identifiable {
    let id = UUID()
    let headline: String
    let soundtrackMood: String
    let previewText: String
    let runtime: TimeInterval
    let scenes: [DreamVideoScene]
}

final class AIDreamService {
    static let shared = AIDreamService()
    private init() {}

    func interpret(session: SleepSession) async throws -> SleepAIResult {
        try await Task.sleep(nanoseconds: 800_000_000) // simulated delay
        let intensity = Double.random(in: 0.2...0.9)
        let consciousness = Double.random(in: 0.1...0.6)
        let moods = DreamMood.allCases
        let mood = moods.randomElement() ?? .peaceful
        let themePool = ["cosmos", "transformation", "ocean", "memory", "rebirth", "serenity", "chaos"]
        let selectedThemes = themePool.shuffled().prefix(3)
        let symbolismPool = ["⭐", "🌀", "🌊", "🔥", "🌿", "🪽", "🌙"]
        let selectedSymbolism = symbolismPool.shuffled().prefix(3)

        let narrative = switch mood {
        case .peaceful:
            "Silvery tides sway beneath a violet sky as you drift weightless, stitching constellations with every calm heartbeat."
        case .calm:
            "A soft river hums through moonlit valleys while gentle lanterns float beside you, whispering forgotten lullabies."
        case .intense:
            "Comets roar overhead and molten petals rise from the ground, pushing you to run faster through the waking horizon."
        case .turbulent:
            "Stormfronts fold into spirals around a glowing tower, each step bending gravity until light snaps like a ribbon."
        case .chaotic:
            "Cities shatter and rebuild in seconds, doors open to oceans, and you laugh as the world spins wildly yet somehow true."
        case .ethereal:
            "Crystalline gardens bloom in zero gravity, their echoes cascading through mirrored clouds you can almost hold."
        }

        let visualPrompt = "Dream aura, mood: \(mood.displayName), particles swirling around luminous orb, palette tuned to mood"

        return SleepAIResult(
            narrative: narrative,
            themes: Array(selectedThemes),
            symbolism: Array(selectedSymbolism),
            intensity: intensity,
            consciousness: consciousness,
            visualPrompt: visualPrompt,
            mood: mood,
            remEstimate: Double.random(in: 18...32),
            deepSleepEstimate: Double.random(in: 20...35)
        )
    }

    func generateVideo(for dream: SleepData) async throws -> DreamVideoResult {
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let palette = dream.mood.colors
        let dominant = palette.first ?? .purple
        let secondary = palette.dropFirst().first ?? .pink

        let opener = DreamVideoScene(
            title: "Lucid Opening",
            subtitle: "Camera glides over luminous clouds formed from \(dream.aiThemes.first ?? "memory")",
            symbol: "sparkles",
            accentColor: dominant,
            duration: 14
        )

        let mid = DreamVideoScene(
            title: "Pulse Bridge",
            subtitle: "Heart-rate \(Int(dream.averageHeartRate)) bpm drives rippling light over an astral river",
            symbol: "waveform.path",
            accentColor: secondary,
            duration: 18
        )

        let finale = DreamVideoScene(
            title: "Reawakening",
            subtitle: "Dream symbol \(dream.aiSymbolism.first ?? "🌙") bursts into particles that dissolve at sunrise",
            symbol: "sunrise.fill",
            accentColor: dominant.opacity(0.8),
            duration: 12
        )

        let runtime = opener.duration + mid.duration + finale.duration
        let soundtrack = dream.mood.displayName + " synth"
        let preview = "AI renders a \(dream.mood.displayName.lowercased()) short film inspired by your \(dream.aiNarrative.prefix(32))..."

        return DreamVideoResult(
            headline: "Dream Film: \(dream.mood.displayName)",
            soundtrackMood: soundtrack,
            previewText: preview,
            runtime: runtime,
            scenes: [opener, mid, finale]
        )
    }
}
