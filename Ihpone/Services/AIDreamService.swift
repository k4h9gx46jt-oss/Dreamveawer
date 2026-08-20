import Foundation
import SwiftUI
import FoundationModels

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
    let startOffset: TimeInterval
    let remSegmentId: UUID?
}

struct DreamVideoResult: Identifiable {
    let id = UUID()
    let headline: String
    let soundtrackMood: String
    let previewText: String
    let runtime: TimeInterval
    let scenes: [DreamVideoScene]
    let videoURL: URL?
    let audioURL: URL?
    let waveform: [Double]
    let diagnostics: [String: String]
}

extension DreamVideoResult {
    /// Files a user can export from the share sheet — the film first, then its score.
    var shareableItems: [URL] {
        [videoURL, audioURL].compactMap { $0 }
    }
}

// MARK: - Foundation Models structured output

@Generable
struct FoundationModelDreamOutput {
    @Guide(description: "A poetic 2-3 sentence narrative that references the specific heart rate, HRV, and REM metrics from the prompt")
    var narrative: String

    @Guide(description: "Exactly 3 dream themes as single lowercase English words derived from the biosignal profile")
    var themes: [String]

    @Guide(description: "Exactly 3 symbolic emoji characters reflecting the emotional quality of the night")
    var symbolism: [String]

    @Guide(description: "A visual style prompt for a dream film renderer, describing mood, colour palette, and atmosphere")
    var visualPrompt: String
}

// MARK: - Biosignal heuristic (deterministic fallback, always runs)

enum BiosignalHeuristic {
    static func analyse(session: SleepSession) -> SleepAIResult {
        let profile = session.remProfile
        let mood = deriveMood(session: session, profile: profile)
        let (remPct, deepPct) = stagePercentages(session: session, profile: profile)
        let intensity = deriveIntensity(session: session, profile: profile)
        let consciousness = deriveConsciousness(session: session, profile: profile)
        return SleepAIResult(
            narrative: composeNarrative(mood: mood, session: session, profile: profile),
            themes: deriveThemes(mood: mood, session: session, profile: profile),
            symbolism: deriveSymbolism(mood: mood, profile: profile),
            intensity: intensity,
            consciousness: consciousness,
            visualPrompt: "Dream aura: \(mood.displayName.lowercased()) palette, biosignal-driven particles, intensity \(String(format: "%.2f", intensity))",
            mood: mood,
            remEstimate: remPct,
            deepSleepEstimate: deepPct
        )
    }

    private static func deriveMood(session: SleepSession, profile: REMDreamProfile?) -> DreamMood {
        guard let profile = profile else {
            if session.averageHeartRate < 55 { return .peaceful }
            return session.hrvAverage > 50 ? .calm : .intense
        }
        let p = profile.moodPolarity    // -1…1
        let i = profile.intensityScore  // 0…1
        let disrupted = profile.apneaSpikeCount + profile.noiseSpikeCount
        if disrupted > 5 { return .chaotic }
        if disrupted > 2 { return p < 0 ? .turbulent : .intense }
        if p > 0.4 && i < 0.4 { return .peaceful }
        if p > 0.2 && i < 0.65 { return .calm }
        if p > 0.1 && i > 0.65 { return .ethereal }
        if i > 0.65 { return .intense }
        if p < -0.2 { return .turbulent }
        return .calm
    }

    private static func stagePercentages(session: SleepSession, profile: REMDreamProfile?) -> (rem: Double, deep: Double) {
        let samples = session.biosignals
        guard !samples.isEmpty else { return (22, 25) }
        let remCount  = samples.filter { $0.sleepStage == .rem  }.count
        let deepCount = samples.filter { $0.sleepStage == .deep }.count
        if remCount + deepCount > 0 {
            let total = Double(samples.count)
            return (Double(remCount) / total * 100, Double(deepCount) / total * 100)
        }
        // Derive from REMDreamProfile when the watch didn't transport stage labels
        if let profile = profile {
            let duration = session.endedAt.map { $0.timeIntervalSince(session.startedAt) } ?? 3600
            guard duration > 0 else { return (22, 25) }
            let remPct = min(50, profile.totalDuration / duration * 100)
            return (remPct, max(10, 28 - (remPct - 22)))
        }
        return (22, 25)
    }

    private static func deriveIntensity(session: SleepSession, profile: REMDreamProfile?) -> Double {
        if let profile = profile { return max(0, min(1, profile.intensityScore)) }
        guard !session.biosignals.isEmpty else { return 0.5 }
        let hrs = session.biosignals.map { $0.heartRate }
        let mean = hrs.reduce(0, +) / Double(hrs.count)
        let variance = hrs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(hrs.count)
        return max(0, min(1, sqrt(variance) / 10))
    }

    private static func deriveConsciousness(session: SleepSession, profile: REMDreamProfile?) -> Double {
        guard let profile = profile else { return 0.3 }
        let duration = session.endedAt.map { $0.timeIntervalSince(session.startedAt) } ?? 3600
        let remFraction = duration > 0 ? min(1, profile.totalDuration / duration) : 0
        let normalizedPolarity = (profile.moodPolarity + 1) / 2
        return max(0, min(1, remFraction * 0.6 + normalizedPolarity * 0.4))
    }

    private static func composeNarrative(mood: DreamMood, session: SleepSession, profile: REMDreamProfile?) -> String {
        let hr  = Int(session.averageHeartRate)
        let hrv = Int(session.hrvAverage)

        // Anchor sentence: reference the longest actual REM window if available
        let anchor: String
        if let profile = profile,
           let peak = profile.segments.max(by: { $0.end.timeIntervalSince($0.start) < $1.end.timeIntervalSince($1.start) }) {
            let minutes = Int(peak.end.timeIntervalSince(peak.start) / 60)
            let cal = Calendar.current
            let hour   = cal.component(.hour,   from: peak.start)
            let minute = cal.component(.minute, from: peak.start)
            anchor = String(format: "Your deepest REM window opened at %02d:%02d, lasting %d min, heart settled at %d bpm.", hour, minute, minutes, Int(peak.heartRateAvg))
        } else {
            anchor = "Your heart held \(hr) bpm through the night, variability at \(hrv) ms."
        }

        // Trend sentence: derived from actual HR and HRV trajectories
        let trend: String
        switch (profile?.heartRateTrend ?? .stable, profile?.hrvTrend ?? .stable) {
        case (.falling, .rising):
            trend = "Heart rate descended while variability rose — the body unwinding into its deepest coherence."
        case (.falling, _):
            trend = "Heart rate fell steadily as the night wore on, each cycle carrying you quieter."
        case (.rising, _):
            trend = "Physiological arousal built toward morning, a slow crescendo that preceded waking."
        case (.stable, .rising):
            trend = "Heart rate stayed even while variability climbed — a signature of sustained restorative sleep."
        default:
            trend = "Rhythm and variability held steady through the night — the hallmark of unbroken rest."
        }

        // Closing sentence: mood-coloured, still references a real metric
        let close: String
        switch mood {
        case .peaceful:  close = "The record reads like still water: \(hrv) ms variability, no turbulence, only depth."
        case .calm:      close = "Measured and steady at \(hrv) ms HRV — a night the body will remember as restoration."
        case .intense:   close = "Peaks of activity punctuate the record; your nervous system drove hard even in sleep at \(hr) bpm."
        case .turbulent: close = "Disrupted arcs and spiking metrics tell of a night the body fought itself."
        case .chaotic:   close = "Noise, rhythm, and motion collided in the small hours — a complex night written in competing signals."
        case .ethereal:  close = "High variability, extended REM: the conditions under which the mind wanders furthest."
        }

        return "\(anchor) \(trend) \(close)"
    }

    private static func deriveThemes(mood: DreamMood, session: SleepSession, profile: REMDreamProfile?) -> [String] {
        var themes: [String] = []
        if let p = profile {
            if p.apneaSpikeCount > 2  { themes.append("struggle") }
            if p.noiseSpikeCount > 2  { themes.append("disruption") }
            if p.intensityScore > 0.6 { themes.append("intensity") }
            if p.moodPolarity > 0.5   { themes.append("serenity") }
            if p.totalDuration > 5400 { themes.append("immersion") }
        }
        if session.hrvAverage > 55        { themes.append("coherence") }
        if session.averageHeartRate < 52  { themes.append("depth") }
        let defaults: [DreamMood: [String]] = [
            .peaceful:  ["stillness", "flow", "restoration"],
            .calm:      ["balance", "rhythm", "continuity"],
            .intense:   ["transformation", "momentum", "surge"],
            .turbulent: ["conflict", "motion", "release"],
            .chaotic:   ["chaos", "entropy", "dissolution"],
            .ethereal:  ["transcendence", "radiance", "void"]
        ]
        for t in defaults[mood] ?? ["rest", "night", "sleep"] where themes.count < 3 {
            themes.append(t)
        }
        return Array(themes.prefix(3))
    }

    private static func deriveSymbolism(mood: DreamMood, profile: REMDreamProfile?) -> [String] {
        var symbols: [String] = []
        if let p = profile {
            switch p.heartRateTrend {
            case .falling: symbols.append("🌊")
            case .rising:  symbols.append("🔥")
            case .stable:  symbols.append("⚖️")
            }
            if p.apneaSpikeCount > 2 { symbols.append("🌀") }
        }
        let defaults: [DreamMood: [String]] = [
            .peaceful:  ["🌿", "🌙", "✨"],
            .calm:      ["🕊️", "🌌", "🌊"],
            .intense:   ["⚡", "🔥", "🌋"],
            .turbulent: ["🌪️", "🌩️", "🌀"],
            .chaotic:   ["💫", "🔮", "🌀"],
            .ethereal:  ["⭐", "🪽", "🌸"]
        ]
        for s in defaults[mood] ?? ["🌙", "⭐", "🌊"] where symbols.count < 3 {
            symbols.append(s)
        }
        return Array(symbols.prefix(3))
    }
}

// MARK: - AIDreamService

final class AIDreamService {
    static let shared = AIDreamService()
    private init() {}

    func interpret(session: SleepSession) async throws -> SleepAIResult {
        let heuristic = BiosignalHeuristic.analyse(session: session)
        guard case .available = SystemLanguageModel.default.availability else {
            return heuristic
        }
        do {
            return try await enrichWithFoundationModels(heuristic: heuristic, session: session)
        } catch {
            return heuristic
        }
    }

    private func enrichWithFoundationModels(heuristic: SleepAIResult, session: SleepSession) async throws -> SleepAIResult {
        let lmSession = LanguageModelSession(
            instructions: "You interpret biosignal data from sleep sessions into poetic dream narratives. Ground every sentence in the specific metrics provided. Do not invent clinical claims or medical diagnoses."
        )
        let response = try await lmSession.respond(
            to: buildPrompt(heuristic: heuristic, session: session),
            generating: FoundationModelDreamOutput.self
        )
        let out = response.content
        return SleepAIResult(
            narrative: out.narrative,
            themes: Array(out.themes.prefix(3)),
            symbolism: Array(out.symbolism.prefix(3)),
            intensity: heuristic.intensity,
            consciousness: heuristic.consciousness,
            visualPrompt: out.visualPrompt,
            mood: heuristic.mood,
            remEstimate: heuristic.remEstimate,
            deepSleepEstimate: heuristic.deepSleepEstimate
        )
    }

    private func buildPrompt(heuristic: SleepAIResult, session: SleepSession) -> String {
        let profile = session.remProfile
        let remMin = profile.map { Int($0.totalDuration / 60) } ?? 0
        return """
        Sleep session biosignals:
        - Average heart rate: \(Int(session.averageHeartRate)) bpm (\(profile?.heartRateTrend.rawValue ?? "stable") trend)
        - Average HRV: \(Int(session.hrvAverage)) ms (\(profile?.hrvTrend.rawValue ?? "stable") trend)
        - Total REM: \(remMin) minutes
        - Apnea events: \(profile?.apneaSpikeCount ?? 0)
        - Noise disruptions: \(profile?.noiseSpikeCount ?? 0)
        - Derived mood: \(heuristic.mood.displayName)

        Write a poetic dream narrative, three themes, three symbolic emoji, and a visual style prompt grounded in these metrics.
        """
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
            duration: 14,
            startOffset: 0,
            remSegmentId: nil
        )

        let mid = DreamVideoScene(
            title: "Pulse Bridge",
            subtitle: "Heart-rate \(Int(dream.averageHeartRate)) bpm drives rippling light over an astral river",
            symbol: "waveform.path",
            accentColor: secondary,
            duration: 18,
            startOffset: 14,
            remSegmentId: nil
        )

        let finale = DreamVideoScene(
            title: "Reawakening",
            subtitle: "Dream symbol \(dream.aiSymbolism.first ?? "🌙") bursts into particles that dissolve at sunrise",
            symbol: "sunrise.fill",
            accentColor: dominant.opacity(0.8),
            duration: 12,
            startOffset: 32,
            remSegmentId: nil
        )

        let runtime = opener.duration + mid.duration + finale.duration
        let soundtrack = dream.mood.displayName + " synth"
        let preview = "AI renders a \(dream.mood.displayName.lowercased()) short film inspired by your \(dream.aiNarrative.prefix(32))..."

        return DreamVideoResult(
            headline: "Dream Film: \(dream.mood.displayName)",
            soundtrackMood: soundtrack,
            previewText: preview,
            runtime: runtime,
            scenes: [opener, mid, finale],
            videoURL: nil,
            audioURL: nil,
            waveform: [],
            diagnostics: [:]
        )
    }
}
