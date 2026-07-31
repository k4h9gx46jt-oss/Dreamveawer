import Foundation
import SwiftUI
import AVFoundation
import UIKit

final class DreamMediaComposer {
    enum Status: Equatable {
        case idle
        case preparing
        case rendering
        case completed
        case failed

        var label: String {
            switch self {
            case .idle: return "Idle"
            case .preparing: return "Analyzing"
            case .rendering: return "Rendering"
            case .completed: return "Ready"
            case .failed: return "Retry"
            }
        }

        var description: String {
            switch self {
            case .idle:
                return "Waiting for a dream session to end."
            case .preparing:
                return "Extracting REM signatures and building prompts."
            case .rendering:
                return "Synthesizing AI film and soundtrack from REM signals."
            case .completed:
                return "Dream film ready to view."
            case .failed:
                return "We couldn't finish this render. Please retry."
            }
        }
    }

    enum ComposerError: LocalizedError {
        case missingREMProfile
        case videoGenerationFailed
        case audioGenerationFailed

        var errorDescription: String? {
            switch self {
            case .missingREMProfile:
                return "No REM profile was available for this session."
            case .videoGenerationFailed:
                return "Video generation could not complete."
            case .audioGenerationFailed:
                return "Audio generation could not complete."
            }
        }
    }

    static let shared = DreamMediaComposer()
    private let cache = DreamMediaCache.shared
    private init() {}

    func composeMedia(for dream: SleepData,
                      progressHandler: (@Sendable (Double) -> Void)? = nil) async throws -> DreamVideoResult {
        guard let profile = dream.remProfile else {
            throw ComposerError.missingREMProfile
        }

        progressHandler?(0.05)
        let prompt = DreamMediaPrompt(dream: dream, profile: profile)
        let scoreProfile = DreamScoreProfile(dream: dream, prompt: prompt)
        let duration = scoreProfile.alignedDuration(target: profile.totalDuration)

        let score = try synthesizeAudio(dream: dream, scoreProfile: scoreProfile, duration: duration)
        progressHandler?(0.3)
        let videoURL = try await synthesizeVideo(prompt: prompt,
                                                 dream: dream,
                                                 duration: duration,
                                                 tempo: Double(scoreProfile.tempo),
                                                 progressHandler: progressHandler)
        let scenes = makeScenes(for: dream, profile: profile)
        let diagnostics = prompt.diagnostics.merging(score.diagnostics) { _, new in new }

        progressHandler?(1.0)

        return DreamVideoResult(
            headline: "Dream Film: \(dream.mood.displayName)",
            soundtrackMood: prompt.soundtrackLabel,
            previewText: prompt.preview,
            runtime: duration,
            scenes: scenes,
            videoURL: videoURL,
            audioURL: score.url,
            waveform: score.waveform,
            diagnostics: diagnostics
        )
    }
}

private extension DreamMediaComposer {
    func synthesizeVideo(prompt: DreamMediaPrompt,
                         dream: SleepData,
                         duration: TimeInterval,
                         tempo: Double,
                         progressHandler: (@Sendable (Double) -> Void)?) async throws -> URL {
        let fileURL = cache.makeURL(fileName: "\(dream.id.uuidString)-video", fileExtension: "mp4")
        try await DreamFilmRenderer.write(to: fileURL,
                                          duration: duration,
                                          tempo: tempo,
                                          profile: prompt.visualProfile,
                                          progressHandler: progressHandler)
        return fileURL
    }

    func synthesizeAudio(dream: SleepData,
                         scoreProfile: DreamScoreProfile,
                         duration: TimeInterval) throws -> DreamScoreRender {
        let fileURL = cache.makeURL(fileName: "\(dream.id.uuidString)-score", fileExtension: "caf")
        try? FileManager.default.removeItem(at: fileURL)
        let waveform = try DreamScoreRenderer.render(to: fileURL, profile: scoreProfile, duration: duration)
        return DreamScoreRender(url: fileURL, waveform: waveform, diagnostics: scoreProfile.diagnostics)
    }

    func makeScenes(for dream: SleepData, profile: REMDreamProfile) -> [DreamVideoScene] {
        let baseStart = profile.segments.first?.start ?? dream.startedAt
        return profile.segments.enumerated().map { index, segment in
            let title: String
            let symbol: String
            switch index {
            case 0: title = "Lucid Opening"; symbol = "sparkles"
            case 1: title = "Pulse Bridge"; symbol = "waveform.path"
            default: title = "Reawakening"; symbol = "sunrise.fill"
            }
            let driverText: String
            switch segment.dominantDriver {
            case .heartRate: driverText = "Pulse surges paint the skyline."
            case .hrv: driverText = "Calm variability smooths the dream."
            case .apnea: driverText = "Breath wavers, sparks ripple."
            case .noise: driverText = "Ambient noise fractures the light."
            case .temperature: driverText = "Thermal drift bends colors."
            case .unknown: driverText = "Subconscious currents shift."
            }
            let subtitle = "HR \(Int(segment.heartRateAvg)) bpm • HRV \(Int(segment.hrvAvg)) ms. \(driverText)"
            let accent = dream.mood.colors[index % dream.mood.colors.count]
            let duration = segment.end.timeIntervalSince(segment.start)
            let offset = max(0, segment.start.timeIntervalSince(baseStart))

            return DreamVideoScene(
                title: title,
                subtitle: subtitle,
                symbol: symbol,
                accentColor: accent,
                duration: duration,
                startOffset: offset,
                remSegmentId: segment.id
            )
        }
    }
}

private struct DreamMediaPrompt {
    let dream: SleepData
    let profile: REMDreamProfile
    let motionEnergy: Double
    let genre: DreamGenre
    let soundtrackLabel: String
    let preview: String
    let visualProfile: DreamVisualProfile

    var diagnostics: [String: String] {
        [
            "intensity": String(format: "%.2f", profile.intensityScore),
            "moodPolarity": String(format: "%.2f", profile.moodPolarity),
            "motionEnergy": String(format: "%.2f", motionEnergy),
            "apneaSpikes": "\(profile.apneaSpikeCount)",
            "noiseSpikes": "\(profile.noiseSpikeCount)"
        ].merging(visualProfile.diagnostics) { _, new in new }
    }

    init(dream: SleepData, profile: REMDreamProfile) {
        self.dream = dream
        self.profile = profile
        self.motionEnergy = max(0.3, min(1.6, profile.intensityScore * 1.5 + Double(profile.apneaSpikeCount) * 0.1))
        let genre = DreamGenre.make(mood: dream.mood, intensity: profile.intensityScore)
        self.genre = genre
        self.soundtrackLabel = genre.soundtrackLabel
        self.preview = "REM energy \(Int(profile.intensityScore * 100))% • mood \(String(format: "%.1f", profile.moodPolarity))"
        self.visualProfile = DreamVisualProfile(mood: dream.mood,
                                                genre: genre,
                                                profile: profile,
                                                seed: makeSeed(from: dream.id))
    }
}

private struct DreamScoreRender {
    let url: URL
    let waveform: [Double]
    let diagnostics: [String: String]
}

/// Musical genre chosen from the dream mood — drives instrumentation, tempo and mix.
enum DreamGenre: String {
    case symphonic
    case chamber
    case celestial
    case cinematic
    case hardRock
    case industrial

    static func make(mood: DreamMood, intensity: Double) -> DreamGenre {
        switch mood {
        case .peaceful:
            return .symphonic
        case .calm:
            return intensity > 0.55 ? .symphonic : .chamber
        case .ethereal:
            return .celestial
        case .intense:
            return intensity > 0.6 ? .hardRock : .cinematic
        case .turbulent:
            return .hardRock
        case .chaotic:
            return .industrial
        }
    }

    var soundtrackLabel: String {
        switch self {
        case .symphonic: return "Symphonic strings, harp & choir"
        case .chamber: return "Chamber ensemble & woodwind"
        case .celestial: return "Celestial choir & glass bells"
        case .cinematic: return "Cinematic hybrid orchestra"
        case .hardRock: return "Hard rock — driven guitars & live drums"
        case .industrial: return "Industrial metal — down-tuned & relentless"
        }
    }
}

private struct DreamScoreProfile {
    enum LeadVoice { case violin, flute, bell, brass, leadGuitar }
    enum ArpVoice { case harp, glass, pluck, palmMute }
    enum Percussion { case orchestral, cinematic, rockKit, metalKit }

    struct LayerGains {
        var pad: Float
        var choir: Float
        var lead: Float
        var arp: Float
        var bass: Float
        var guitar: Float
        var drums: Float
    }

    /// One melodic event: a scale degree (or a rest) and its length in sixteenth steps.
    struct MelodyNote {
        let degree: Int?
        let steps: Int
    }

    let genre: DreamGenre
    let tempo: Float
    let beatsPerBar: Int
    let barsPerChord: Int
    let tonicHz: Float
    let scale: [Float]
    let progression: [Int]
    /// Consecutive four-bar phrases; the renderer cycles them so the tune does not loop every bar.
    let melodyPhrases: [[MelodyNote]]
    let ornamentChance: Float
    /// Chord-tone indices on an eighth-note grid; values ≥ 4 shift up an octave.
    let arpPattern: [Int?]
    /// Scale-step offsets from the chord root on a sixteenth grid.
    let riff: [Int?]
    let bassPattern: [Int?]
    let kickPattern: [Float]
    let snarePattern: [Float]
    let hatPattern: [Float]
    let leadVoice: LeadVoice
    let arpVoice: ArpVoice
    let percussion: Percussion
    let gains: LayerGains
    let harmonyAmount: Float
    let drive: Float
    let brightness: Float
    let reverbMix: Float
    let reverbSize: Float
    let delayMix: Float
    let delaySeconds: Float
    let stereoWidth: Float
    let seed: UInt64

    var diagnostics: [String: String] {
        [
            "genre": genre.rawValue,
            "tempo": String(format: "%.0f BPM", tempo),
            "key": String(format: "%.1f Hz", tonicHz),
            "channels": "stereo"
        ]
    }

    /// Snaps the requested runtime to whole bars so the score and film loop seamlessly together.
    func alignedDuration(target: TimeInterval) -> TimeInterval {
        let secondsPerBar = Float(beatsPerBar) * 60 / tempo
        let requested = min(max(Float(target), 34), 58)
        let bars = max(4, Int((requested / secondsPerBar).rounded()))
        return TimeInterval(min(Float(bars) * secondsPerBar, 60))
    }

    /// Every genre has its own melodic character, split into a flowing and an agitated variant.
    /// Each phrase is exactly four bars (64 sixteenth steps).
    private static func melodyBank(genre: DreamGenre, agitated: Bool) -> [[MelodyNote]] {
        func n(_ degree: Int?, _ steps: Int) -> MelodyNote { MelodyNote(degree: degree, steps: steps) }

        switch (genre, agitated) {
        case (.symphonic, false):
            return [
                [n(4, 8), n(6, 4), n(7, 4), n(9, 8), n(7, 4), n(6, 4),
                 n(4, 6), n(2, 2), n(4, 8), n(2, 8), n(0, 4), n(nil, 4)],
                [n(7, 4), n(9, 4), n(11, 8), n(9, 6), n(7, 2), n(6, 8),
                 n(4, 4), n(6, 4), n(7, 8), n(6, 8), n(4, 8)],
                [n(0, 4), n(2, 4), n(4, 8), n(6, 4), n(7, 4), n(9, 8),
                 n(7, 4), n(6, 4), n(4, 4), n(2, 4), n(0, 12), n(nil, 4)]
            ]
        case (.symphonic, true):
            return [
                [n(4, 4), n(7, 2), n(9, 2), n(11, 4), n(9, 4), n(7, 4), n(4, 4), n(6, 4), n(2, 4),
                 n(4, 2), n(6, 2), n(7, 4), n(11, 8), n(9, 4), n(7, 4), n(4, 8)],
                [n(9, 4), n(11, 4), n(12, 8), n(11, 4), n(9, 4), n(7, 8),
                 n(6, 2), n(7, 2), n(9, 4), n(11, 4), n(9, 4), n(7, 4), n(4, 4), n(2, 8)],
                [n(2, 2), n(4, 2), n(6, 4), n(9, 8), n(7, 4), n(6, 4), n(4, 8),
                 n(7, 2), n(9, 2), n(11, 4), n(13, 8), n(11, 4), n(9, 4), n(7, 8)]
            ]
        case (.chamber, false):
            return [
                [n(0, 4), n(2, 2), n(4, 2), n(5, 4), n(4, 4), n(2, 4), n(4, 4), n(6, 8),
                 n(4, 2), n(5, 2), n(4, 4), n(2, 4), n(0, 4), n(2, 8), n(0, 8)],
                [n(4, 2), n(5, 2), n(6, 4), n(4, 8), n(2, 2), n(3, 2), n(4, 4), n(6, 8),
                 n(7, 4), n(6, 2), n(5, 2), n(4, 8), n(2, 4), n(4, 4), n(0, 8)],
                [n(6, 4), n(4, 4), n(2, 4), n(4, 4), n(5, 2), n(6, 2), n(7, 4), n(6, 8),
                 n(4, 4), n(2, 4), n(0, 8), n(2, 2), n(4, 2), n(6, 4), n(4, 8)]
            ]
        case (.chamber, true):
            return [
                [n(0, 2), n(2, 2), n(4, 2), n(6, 2), n(7, 4), n(6, 4),
                 n(4, 2), n(6, 2), n(7, 4), n(9, 8),
                 n(7, 2), n(6, 2), n(4, 4), n(2, 4), n(4, 4), n(6, 4), n(4, 4), n(0, 8)],
                [n(7, 2), n(6, 2), n(7, 4), n(9, 8), n(7, 4), n(4, 4), n(6, 4), n(2, 4),
                 n(4, 2), n(5, 2), n(6, 2), n(7, 2), n(9, 8), n(7, 4), n(6, 4), n(4, 8)],
                [n(2, 2), n(4, 2), n(6, 4), n(7, 8), n(9, 4), n(7, 4), n(6, 4), n(4, 4),
                 n(2, 2), n(4, 2), n(6, 4), n(9, 8), n(7, 4), n(4, 4), n(2, 8)]
            ]
        case (.celestial, false):
            return [
                [n(0, 8), n(4, 8), n(6, 12), n(7, 4), n(9, 8), n(6, 8), n(4, 12), n(nil, 4)],
                [n(7, 8), n(9, 8), n(11, 12), n(9, 4), n(7, 8), n(4, 8), n(6, 16)],
                [n(4, 8), n(6, 8), n(9, 12), n(11, 4), n(13, 8), n(9, 8), n(7, 16)]
            ]
        case (.celestial, true):
            return [
                [n(4, 4), n(6, 4), n(7, 8), n(9, 4), n(11, 4), n(9, 8),
                 n(7, 4), n(6, 4), n(4, 8), n(2, 8), n(4, 8)],
                [n(7, 4), n(9, 4), n(11, 8), n(13, 4), n(11, 4), n(9, 8),
                 n(7, 4), n(9, 4), n(6, 8), n(4, 16)],
                [n(6, 4), n(7, 4), n(9, 8), n(11, 8), n(13, 8),
                 n(11, 4), n(9, 4), n(7, 8), n(6, 8), n(4, 8)]
            ]
        case (.cinematic, false):
            return [
                [n(0, 4), n(4, 4), n(7, 8), n(6, 4), n(4, 4), n(2, 8),
                 n(4, 4), n(7, 4), n(9, 8), n(7, 8), n(4, 8)],
                [n(7, 4), n(6, 4), n(4, 8), n(2, 4), n(4, 4), n(7, 8),
                 n(9, 4), n(7, 4), n(6, 8), n(4, 8), n(0, 8)],
                [n(4, 8), n(7, 4), n(9, 4), n(11, 8), n(9, 8),
                 n(7, 4), n(6, 4), n(4, 8), n(2, 8), n(4, 8)]
            ]
        case (.cinematic, true):
            return [
                [n(0, 3), n(0, 3), n(4, 2), n(7, 4), n(6, 4),
                 n(4, 3), n(4, 3), n(2, 2), n(7, 8),
                 n(9, 3), n(7, 3), n(6, 2), n(4, 4), n(2, 4), n(4, 4), n(7, 4), n(0, 8)],
                [n(7, 2), n(7, 2), n(9, 4), n(7, 4), n(6, 4),
                 n(4, 2), n(4, 2), n(6, 4), n(9, 8),
                 n(7, 2), n(7, 2), n(6, 4), n(4, 4), n(2, 4), n(0, 4), n(4, 4), n(7, 8)],
                [n(4, 4), n(6, 2), n(7, 2), n(9, 8), n(7, 3), n(6, 3), n(4, 2), n(2, 8),
                 n(4, 2), n(7, 2), n(9, 4), n(11, 8), n(9, 4), n(7, 4), n(4, 8)]
            ]
        case (.hardRock, false):
            return [
                [n(0, 4), n(2, 4), n(4, 8), n(2, 4), n(0, 4), n(4, 8),
                 n(7, 4), n(4, 4), n(2, 8), n(0, 8), n(nil, 8)],
                [n(4, 4), n(7, 4), n(6, 8), n(4, 4), n(2, 4), n(0, 8),
                 n(4, 2), n(6, 2), n(7, 4), n(9, 8), n(7, 4), n(4, 4), n(2, 8)],
                [n(7, 8), n(6, 4), n(4, 4), n(2, 4), n(4, 4), n(0, 8),
                 n(4, 4), n(7, 4), n(9, 8), n(7, 8), n(4, 8)]
            ]
        case (.hardRock, true):
            return [
                [n(0, 2), n(4, 2), n(7, 2), n(6, 2), n(4, 4), n(2, 4),
                 n(0, 2), n(4, 2), n(7, 4), n(9, 8),
                 n(7, 2), n(6, 2), n(4, 2), n(2, 2), n(0, 8), n(4, 4), n(7, 4), n(11, 8)],
                [n(7, 2), n(9, 2), n(11, 4), n(9, 4), n(7, 4),
                 n(6, 2), n(4, 2), n(2, 4), n(0, 8),
                 n(4, 2), n(7, 2), n(9, 2), n(11, 2), n(9, 8), n(7, 4), n(4, 4), n(0, 8)],
                [n(4, 3), n(4, 3), n(7, 2), n(6, 4), n(4, 4),
                 n(2, 3), n(2, 3), n(4, 2), n(0, 8),
                 n(7, 2), n(9, 2), n(7, 4), n(6, 4), n(4, 4), n(2, 4), n(0, 4), n(4, 8)]
            ]
        case (.industrial, false):
            return [
                [n(0, 4), n(1, 4), n(0, 8), n(3, 4), n(1, 4), n(0, 8),
                 n(4, 4), n(3, 4), n(1, 8), n(0, 16)],
                [n(4, 4), n(3, 4), n(1, 8), n(0, 4), n(1, 4), n(3, 8),
                 n(4, 4), n(5, 4), n(4, 8), n(1, 8), n(0, 8)],
                [n(1, 4), n(0, 4), n(4, 8), n(3, 4), n(1, 4), n(0, 8),
                 n(5, 4), n(4, 4), n(3, 8), n(1, 8), n(0, 8)]
            ]
        case (.industrial, true):
            return [
                [n(0, 2), n(1, 2), n(0, 2), n(3, 2), n(4, 4), n(3, 4),
                 n(1, 2), n(0, 2), n(1, 4), n(0, 8),
                 n(4, 2), n(5, 2), n(4, 4), n(3, 4), n(1, 4), n(0, 4), n(1, 4), n(0, 8)],
                [n(4, 2), n(4, 2), n(3, 4), n(1, 8), n(0, 2), n(0, 2), n(1, 4), n(4, 8),
                 n(5, 2), n(4, 2), n(3, 4), n(1, 4), n(0, 4), n(1, 4), n(0, 4), n(4, 8)],
                [n(0, 3), n(0, 3), n(1, 2), n(0, 4), n(3, 4),
                 n(4, 3), n(3, 3), n(1, 2), n(0, 8),
                 n(0, 2), n(3, 2), n(4, 4), n(5, 8), n(4, 4), n(1, 4), n(0, 8)]
            ]
        }
    }

    init(dream: SleepData, prompt: DreamMediaPrompt) {
        let rem = prompt.profile
        let intensity = Float(min(max(rem.intensityScore, 0), 1))
        let polarity = Float(rem.moodPolarity)
        let apnea = Float(rem.apneaSpikeCount)
        let noiseSpikes = Float(rem.noiseSpikeCount)
        let genre = prompt.genre
        self.genre = genre

        let startBits = UInt64(bitPattern: Int64(dream.startedAt.timeIntervalSince1970.rounded()))
        let seed = makeSeed(from: dream.id) ^ (startBits &* 0x9E37_79B9_7F4A_7C15)
        self.seed = seed
        var rng = DreamRandom(seed: seed)

        let averageHR = rem.segments.isEmpty
            ? 62
            : rem.segments.reduce(0) { $0 + $1.heartRateAvg } / Double(rem.segments.count)
        let pulse = Float(min(max((averageHR - 46) / 42, 0), 1))

        let tempoRange: (Float, Float)
        switch genre {
        case .symphonic: tempoRange = (56, 74)
        case .chamber: tempoRange = (64, 84)
        case .celestial: tempoRange = (48, 64)
        case .cinematic: tempoRange = (82, 102)
        case .hardRock: tempoRange = (122, 148)
        case .industrial: tempoRange = (138, 172)
        }
        let tempoBlend = min(max(pulse * 0.6 + intensity * 0.3 + rng.nextFloat() * 0.2 - 0.1, 0), 1)
        tempo = tempoRange.0 + (tempoRange.1 - tempoRange.0) * tempoBlend
        beatsPerBar = 4
        barsPerChord = genre == .celestial ? 2 : 1

        let keySteps: [Float] = [0, 2, 3, 5, 7, 8, 10]
        let keyStep = keySteps[Int(rng.nextFloat() * Float(keySteps.count)) % keySteps.count]
        let baseHz: Float
        switch genre {
        case .symphonic, .chamber: baseHz = 130.81
        case .celestial: baseHz = 146.83
        case .cinematic: baseHz = 110.00
        case .hardRock: baseHz = 82.41
        case .industrial: baseHz = 73.42
        }
        tonicHz = baseHz * powf(2, keyStep / 12)

        let major: [Float] = [0, 2, 4, 5, 7, 9, 11]
        let lydian: [Float] = [0, 2, 4, 6, 7, 9, 11]
        let dorian: [Float] = [0, 2, 3, 5, 7, 9, 10]
        let aeolian: [Float] = [0, 2, 3, 5, 7, 8, 10]
        let phrygian: [Float] = [0, 1, 3, 5, 7, 8, 10]
        switch genre {
        case .symphonic: scale = polarity >= 0 ? major : dorian
        case .chamber: scale = major
        case .celestial: scale = lydian
        case .cinematic: scale = aeolian
        case .hardRock: scale = intensity > 0.7 ? phrygian : aeolian
        case .industrial: scale = phrygian
        }

        let progressionBank: [[Int]]
        switch genre {
        case .symphonic: progressionBank = [[0, 4, 5, 3], [0, 3, 4, 0], [5, 3, 0, 4], [0, 5, 1, 4]]
        case .chamber: progressionBank = [[0, 3, 0, 4], [0, 5, 3, 4], [1, 4, 0, 0]]
        case .celestial: progressionBank = [[0, 4, 5, 1], [0, 1, 4, 0], [5, 1, 0, 4]]
        case .cinematic: progressionBank = [[0, 5, 3, 4], [0, 2, 5, 4], [0, 6, 5, 4]]
        case .hardRock: progressionBank = [[0, 0, 5, 3], [0, 3, 4, 0], [0, 6, 5, 4], [0, 0, 2, 4]]
        case .industrial: progressionBank = [[0, 1, 0, 4], [0, 4, 1, 0], [0, 0, 1, 6]]
        }
        progression = progressionBank[Int(rng.nextFloat() * Float(progressionBank.count)) % progressionBank.count]

        // Calmer dreams get the flowing bank, restless ones the agitated bank of the same genre.
        let agitated = intensity >= 0.5 || abs(polarity) > 0.62
        melodyPhrases = Self.melodyBank(genre: genre, agitated: agitated)
        ornamentChance = min(0.6, 0.08 + intensity * 0.5)

        let arpBank: [[Int?]] = [
            [0, 1, 2, 3, 4, 3, 2, 1, 0, 2, 4, 3, 2, 1, 0, 1],
            [0, 2, 1, 3, 2, 4, 3, 1, 2, 0, 3, 1, 4, 2, 3, 1],
            [0, 1, 2, 4, 2, 1, 0, 2, 3, 1, 4, 2, 1, 3, 0, 2],
            [0, 3, 1, 4, 2, 5, 3, 1, 4, 2, 5, 3, 2, 4, 1, 0]
        ]
        arpPattern = arpBank[Int(rng.nextFloat() * Float(arpBank.count)) % arpBank.count]

        let riffBank: [[Int?]] = [
            [0, nil, 0, 0, nil, 0, 0, nil, 0, nil, 0, 0, 2, nil, 1, nil],
            [0, 0, nil, 0, 0, nil, 0, 0, nil, 0, 0, nil, 3, nil, 2, nil],
            [0, nil, nil, nil, 0, nil, nil, nil, 2, nil, nil, nil, 1, nil, 0, nil],
            [0, 0, 0, 0, 2, 2, 0, 0, 1, 1, 0, 0, 4, nil, 3, nil]
        ]
        let chosenRiff = riffBank[Int(rng.nextFloat() * Float(riffBank.count)) % riffBank.count]
        riff = chosenRiff

        switch genre {
        case .hardRock, .industrial:
            bassPattern = chosenRiff
        case .cinematic:
            bassPattern = [0, nil, nil, nil, 0, nil, nil, nil, 4, nil, nil, nil, 0, nil, nil, nil]
        default:
            let walkingBass: [[Int?]] = [
                [0, nil, nil, nil, nil, nil, nil, nil, 4, nil, nil, nil, 2, nil, nil, nil],
                [0, nil, nil, nil, 2, nil, nil, nil, 4, nil, nil, nil, 6, nil, nil, nil],
                [0, nil, nil, nil, nil, nil, 4, nil, 2, nil, nil, nil, nil, nil, -3, nil],
                [0, nil, nil, nil, 4, nil, nil, nil, 2, nil, nil, nil, -3, nil, nil, nil]
            ]
            bassPattern = walkingBass[Int(rng.nextFloat() * Float(walkingBass.count)) % walkingBass.count]
        }

        switch genre {
        case .symphonic, .chamber, .celestial:
            percussion = .orchestral
            kickPattern = [0.8, 0, 0, 0, 0, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 0, 0]
            snarePattern = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            hatPattern = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .cinematic:
            percussion = .cinematic
            kickPattern = [1, 0, 0, 0, 0, 0, 0.7, 0, 1, 0, 0, 0, 0, 0, 0.7, 0]
            snarePattern = [0, 0, 0, 0, 0.8, 0, 0, 0, 0, 0, 0, 0, 0.8, 0, 0, 0.4]
            hatPattern = [0, 0, 0.3, 0, 0, 0, 0.3, 0, 0, 0, 0.3, 0, 0, 0, 0.3, 0]
        case .hardRock:
            percussion = .rockKit
            kickPattern = [1, 0, 0, 0, 0, 0, 0.85, 0, 0, 0, 1, 0, 0, 0.6, 0, 0]
            snarePattern = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0.45]
            hatPattern = [0.85, 0, 0.5, 0, 0.8, 0, 0.5, 0, 0.85, 0, 0.5, 0, 0.8, 0, 0.55, 0.35]
        case .industrial:
            percussion = .metalKit
            kickPattern = [1, 0, 0.9, 0.9, 0, 0.9, 0.9, 0, 1, 0, 0.9, 0.9, 0, 0.9, 0, 0.9]
            snarePattern = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0.5]
            hatPattern = [0.7, 0, 0.7, 0, 0.7, 0, 0.7, 0, 0.7, 0, 0.7, 0, 0.7, 0, 0.7, 0.5]
        }

        let baseDrive: Float
        let baseBrightness: Float
        let baseReverbMix: Float
        let baseWidth: Float

        switch genre {
        case .symphonic:
            leadVoice = .violin
            arpVoice = .harp
            gains = LayerGains(pad: 0.50, choir: 0.40, lead: 1.35, arp: 0.75, bass: 0.85, guitar: 0, drums: 0.45)
            harmonyAmount = 0.55
            baseDrive = 0.03
            baseBrightness = 0.45
            baseReverbMix = 0.34
            reverbSize = 0.88
            delayMix = 0.14
            baseWidth = 0.95
        case .chamber:
            leadVoice = .flute
            arpVoice = .pluck
            gains = LayerGains(pad: 0.42, choir: 0.25, lead: 1.40, arp: 0.85, bass: 0.75, guitar: 0, drums: 0.3)
            harmonyAmount = 0.45
            baseDrive = 0.02
            baseBrightness = 0.55
            baseReverbMix = 0.28
            reverbSize = 0.8
            delayMix = 0.12
            baseWidth = 0.8
        case .celestial:
            leadVoice = .bell
            arpVoice = .glass
            gains = LayerGains(pad: 0.60, choir: 0.55, lead: 1.20, arp: 0.90, bass: 0.6, guitar: 0, drums: 0.2)
            harmonyAmount = 0.4
            baseDrive = 0.02
            baseBrightness = 0.7
            baseReverbMix = 0.44
            reverbSize = 0.92
            delayMix = 0.3
            baseWidth = 1.0
        case .cinematic:
            leadVoice = .brass
            arpVoice = .pluck
            gains = LayerGains(pad: 0.45, choir: 0.35, lead: 1.35, arp: 0.6, bass: 1.0, guitar: 0.35, drums: 0.95)
            harmonyAmount = 0.6
            baseDrive = 0.22
            baseBrightness = 0.6
            baseReverbMix = 0.30
            reverbSize = 0.84
            delayMix = 0.16
            baseWidth = 0.9
        case .hardRock:
            leadVoice = .leadGuitar
            arpVoice = .palmMute
            gains = LayerGains(pad: 0.18, choir: 0.10, lead: 1.25, arp: 0.35, bass: 1.0, guitar: 1.0, drums: 1.0)
            harmonyAmount = 0.5
            baseDrive = 0.62 + intensity * 0.2
            baseBrightness = 0.72
            baseReverbMix = 0.17
            reverbSize = 0.7
            delayMix = 0.14
            baseWidth = 0.85
        case .industrial:
            leadVoice = .leadGuitar
            arpVoice = .palmMute
            gains = LayerGains(pad: 0.15, choir: 0.12, lead: 1.15, arp: 0.3, bass: 1.0, guitar: 1.0, drums: 1.0)
            harmonyAmount = 0.35
            baseDrive = 0.78 + intensity * 0.18
            baseBrightness = 0.8
            baseReverbMix = 0.14
            reverbSize = 0.62
            delayMix = 0.1
            baseWidth = 0.75
        }

        // Apnea and ambient-noise spikes push the mix toward a rawer, wider, more driven sound.
        drive = min(0.95, baseDrive + min(apnea, 8) * 0.012)
        brightness = min(1, baseBrightness + min(noiseSpikes, 12) * 0.008)
        reverbMix = min(0.7, baseReverbMix + min(apnea, 6) * 0.008)
        stereoWidth = min(1, baseWidth + min(noiseSpikes, 10) * 0.006)
        delaySeconds = (60 / tempo) * (genre == .hardRock || genre == .industrial ? 0.75 : 1.0)
    }
}

private final class DreamMediaCache {
    static let shared = DreamMediaCache()
    private let directory: URL
    private let fileManager = FileManager.default

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = caches.appendingPathComponent("DreamMediaCache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func makeURL(fileName: String, fileExtension: String) -> URL {
        directory.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
    }
}

private enum DreamScoreRenderer {
    /// Renders a stereo, tempo-locked arrangement and returns a normalised RMS waveform for the UI.
    static func render(to url: URL, profile: DreamScoreProfile, duration: TimeInterval) throws -> [Double] {
        let sampleRate: Double = 44_100
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(max(1, Int(duration * sampleRate)))
        guard format.channelCount == 2,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else {
            throw DreamMediaComposer.ComposerError.audioGenerationFailed
        }
        buffer.frameLength = frameCount
        let outputL = channels[0]
        let outputR = channels[1]

        let sr = Float(sampleRate)
        let delta = 1 / sr
        let totalFrames = Int(frameCount)
        let totalSeconds = max(Float(duration), 1)
        let secondsPerStep = 15 / profile.tempo
        let stepsPerBar = profile.beatsPerBar * 4
        let stepsPerChord = stepsPerBar * profile.barsPerChord
        let heavy = profile.genre == .hardRock || profile.genre == .industrial
        // Distorted genres sit an octave lower, so the sustained voices move up to keep the low end clear.
        let voiceOctave: Float = heavy ? 12 : 0

        func scaleSemitone(_ degree: Int) -> Float {
            let count = profile.scale.count
            var octave = degree / count
            var index = degree % count
            if index < 0 {
                index += count
                octave -= 1
            }
            return profile.scale[index] + Float(octave * 12)
        }

        func frequency(_ semitones: Float) -> Float {
            profile.tonicHz * powf(2, semitones / 12)
        }

        func sectionTargets(_ position: Float) -> (Float, Float, Float, Float, Float, Float, Float) {
            switch position {
            case ..<0.10: return (1.00, 0.70, 0.45, 0.45, 0.35, 0.00, 0.00)
            case ..<0.28: return (0.90, 0.45, 0.80, 0.85, 0.90, 0.55, 0.60)
            case ..<0.50: return (1.00, 0.80, 1.00, 0.90, 1.00, 1.00, 1.00)
            case ..<0.64: return (0.95, 1.00, 0.70, 0.60, 0.65, 0.35, 0.45)
            case ..<0.88: return (1.00, 0.95, 1.00, 1.00, 1.00, 1.00, 1.00)
            default: return (0.85, 0.75, 0.60, 0.50, 0.50, 0.25, 0.20)
            }
        }

        var chordTones: [Float] = [0, 2, 4, 6].map { scaleSemitone($0) }
        var chordRootDegree = 0

        var padPhase = [Float](repeating: 0, count: 8)
        var padFrequency = [Float](repeating: profile.tonicHz, count: 8)
        var padTarget = [Float](repeating: profile.tonicHz, count: 8)
        var choirPhase = [Float](repeating: 0, count: 3)
        var choirFrequency = [Float](repeating: profile.tonicHz, count: 3)
        var choirTarget = [Float](repeating: profile.tonicHz, count: 3)

        var guitarPhase = [Float](repeating: 0, count: 6)
        var guitarFrequency = [Float](repeating: profile.tonicHz, count: 6)
        var guitarAge: Float = 99
        var guitarGate: Float = 0.2

        var bassPhase: Float = 0
        var subPhase: Float = 0
        var bassFrequency = profile.tonicHz * 0.5
        var bassAge: Float = 99

        var leadPhaseA: Float = 0
        var leadPhaseB: Float = 0
        var leadFrequency = profile.tonicHz * 2
        var leadAge: Float = 99
        var leadGate: Float = 0.4
        var melodyIndex = 0
        var melodyNextStep = 0
        var phraseIndex = 0
        var leadGraceFrequency: Float = 0
        var leadGraceTime: Float = 0
        var harmonyPhase: Float = 0
        var harmonyFrequency = profile.tonicHz * 2
        var padAge: Float = 0

        var arpPhase: Float = 0
        var arpFrequency = profile.tonicHz * 2
        var arpAge: Float = 99
        var arpPan: Float = -0.5

        var kickAge: Float = 99
        var kickVelocity: Float = 0
        var snareAge: Float = 99
        var snareVelocity: Float = 0
        var hatAge: Float = 99
        var hatVelocity: Float = 0
        var crashAge: Float = 99

        var padFilterL = StateVariableFilter()
        var padFilterR = StateVariableFilter()
        var leadFilter = StateVariableFilter()
        var harmonyFilter = StateVariableFilter()
        var bassFilter = StateVariableFilter()
        var guitarCabA = OnePoleFilter(cutoffHz: 3600, sampleRate: sr)
        var guitarCabB = OnePoleFilter(cutoffHz: 3600, sampleRate: sr)
        var guitarBodyA = OnePoleFilter(cutoffHz: 110, sampleRate: sr)
        var guitarBodyB = OnePoleFilter(cutoffHz: 110, sampleRate: sr)
        var hatFilter = OnePoleFilter(cutoffHz: 7000, sampleRate: sr)
        var snareLow = OnePoleFilter(cutoffHz: 6500, sampleRate: sr)
        var snareHigh = OnePoleFilter(cutoffHz: 320, sampleRate: sr)
        var crashFilter = OnePoleFilter(cutoffHz: 4200, sampleRate: sr)
        var crashFilterR = OnePoleFilter(cutoffHz: 4200, sampleRate: sr)
        var dcBlockerL = DCBlocker()
        var dcBlockerR = DCBlocker()
        var reverbL = ReverbChannel(offset: 0, roomSize: profile.reverbSize, damping: 0.3)
        var reverbR = ReverbChannel(offset: 23, roomSize: profile.reverbSize, damping: 0.3)
        var delay = PingPongDelay(sampleRate: sr, time: profile.delaySeconds, feedback: 0.36)
        var limiter = Limiter(threshold: 0.9)
        var rng = DreamRandom(seed: profile.seed &+ 0x5DEE_CE66_D)

        var mixPad: Float = 0
        var mixChoir: Float = 0
        var mixLead: Float = 0
        var mixArp: Float = 0
        var mixBass: Float = 0
        var mixGuitar: Float = 0
        var mixDrums: Float = 0

        let waveformBuckets = 80
        var waveformSums = [Double](repeating: 0, count: waveformBuckets)
        var waveformCounts = [Int](repeating: 0, count: waveformBuckets)

        var lastStep = -1
        for frame in 0..<totalFrames {
            let time = Float(frame) / sr
            let currentStep = Int(time / secondsPerStep)

            if currentStep != lastStep {
                lastStep = currentStep
                let stepInBar = currentStep % stepsPerBar

                if currentStep % stepsPerChord == 0 {
                    let chordIndex = currentStep / stepsPerChord
                    chordRootDegree = profile.progression[chordIndex % profile.progression.count]
                    padAge = 0
                    chordTones = [
                        scaleSemitone(chordRootDegree),
                        scaleSemitone(chordRootDegree + 2),
                        scaleSemitone(chordRootDegree + 4),
                        scaleSemitone(chordRootDegree + 6)
                    ]
                    for voice in 0..<8 {
                        let tone = chordTones[voice % 4]
                        let octave: Float = voice < 4 ? 0 : 12
                        let detune: Float = voice < 4 ? -0.07 : 0.07
                        padTarget[voice] = frequency(tone + voiceOctave + octave + detune)
                    }
                    choirTarget[0] = frequency(chordTones[0] + voiceOctave - 12)
                    choirTarget[1] = frequency(chordTones[1] + voiceOctave)
                    choirTarget[2] = frequency(chordTones[2] + voiceOctave + 12)
                }

                if profile.gains.guitar > 0,
                   let offset = profile.riff[stepInBar % profile.riff.count] {
                    let root = scaleSemitone(chordRootDegree + offset)
                    let voicing: [Float] = [root, root + 7, root + 12]
                    for voice in 0..<6 {
                        let detune: Float = voice < 3 ? -0.09 : 0.09
                        guitarFrequency[voice] = frequency(voicing[voice % 3] + detune)
                    }
                    guitarAge = 0
                    var length = secondsPerStep
                    var lookahead = 1
                    while lookahead < 8, profile.riff[(stepInBar + lookahead) % profile.riff.count] == nil {
                        length += secondsPerStep
                        lookahead += 1
                    }
                    guitarGate = length * 0.9
                }

                if let offset = profile.bassPattern[stepInBar % profile.bassPattern.count] {
                    let note = scaleSemitone(chordRootDegree + offset)
                    bassFrequency = frequency(note - (heavy ? 0 : 12))
                    bassAge = 0
                }

                // Each four-bar block advances to the next phrase, so the tune runs long-form.
                if currentStep % (stepsPerBar * 4) == 0 {
                    phraseIndex = (currentStep / (stepsPerBar * 4)) % max(1, profile.melodyPhrases.count)
                    melodyIndex = 0
                    melodyNextStep = currentStep
                }
                if currentStep >= melodyNextStep, !profile.melodyPhrases.isEmpty {
                    let phrase = profile.melodyPhrases[phraseIndex]
                    let note = phrase[melodyIndex % max(1, phrase.count)]
                    melodyIndex += 1
                    melodyNextStep = currentStep + max(1, note.steps)
                    if let degree = note.degree {
                        leadFrequency = frequency(scaleSemitone(degree) + 12 + voiceOctave)
                        harmonyFrequency = frequency(scaleSemitone(degree - 2) + 12 + voiceOctave)
                        leadAge = 0
                        leadGate = Float(note.steps) * secondsPerStep * 0.88
                        if note.steps >= 4, rng.nextFloat() < profile.ornamentChance {
                            leadGraceFrequency = frequency(scaleSemitone(degree + 1) + 12 + voiceOctave)
                            leadGraceTime = min(0.07, secondsPerStep * 0.45)
                        } else {
                            leadGraceTime = 0
                        }
                    }
                }

                if currentStep % 2 == 0 {
                    let arpIndex = (currentStep / 2) % profile.arpPattern.count
                    if let toneIndex = profile.arpPattern[arpIndex] {
                        let tone = chordTones[toneIndex % 4] + Float((toneIndex / 4) * 12)
                        arpFrequency = frequency(tone + (heavy ? 0 : 12))
                        arpAge = 0
                        arpPan = arpIndex % 2 == 0 ? -0.55 : 0.55
                    }
                }

                let kickHit = profile.kickPattern[stepInBar % profile.kickPattern.count]
                if kickHit > 0 {
                    kickAge = 0
                    kickVelocity = kickHit
                }
                let snareHit = profile.snarePattern[stepInBar % profile.snarePattern.count]
                if snareHit > 0 {
                    snareAge = 0
                    snareVelocity = snareHit
                }
                let hatHit = profile.hatPattern[stepInBar % profile.hatPattern.count]
                if hatHit > 0 {
                    hatAge = 0
                    hatVelocity = hatHit
                }
                if currentStep % (stepsPerBar * 8) == 0 {
                    crashAge = 0
                }
            }

            guitarAge += delta
            bassAge += delta
            leadAge += delta
            arpAge += delta
            padAge += delta
            kickAge += delta
            snareAge += delta
            hatAge += delta
            crashAge += delta

            let targets = sectionTargets(time / totalSeconds)
            let smoothing: Float = 0.0003
            mixPad += (targets.0 - mixPad) * smoothing
            mixChoir += (targets.1 - mixChoir) * smoothing
            mixLead += (targets.2 - mixLead) * smoothing
            mixArp += (targets.3 - mixArp) * smoothing
            mixBass += (targets.4 - mixBass) * smoothing
            mixGuitar += (targets.5 - mixGuitar) * smoothing
            mixDrums += (targets.6 - mixDrums) * smoothing

            let padGain = mixPad * profile.gains.pad
            let choirGain = mixChoir * profile.gains.choir
            let leadGain = mixLead * profile.gains.lead
            // Thirds only join in once the arrangement opens up.
            let harmonyGain = leadGain * profile.harmonyAmount * min(1, max(0, mixLead - 0.6) / 0.4)
            let arpGain = mixArp * profile.gains.arp
            let bassGain = mixBass * profile.gains.bass
            let guitarGain = mixGuitar * profile.gains.guitar
            let drumGain = mixDrums * profile.gains.drums

            var padL: Float = 0
            var padR: Float = 0
            if padGain > 0.002 {
                var sumL: Float = 0
                var sumR: Float = 0
                for voice in 0..<8 {
                    padFrequency[voice] += (padTarget[voice] - padFrequency[voice]) * 0.0025
                    let vibrato = 1 + 0.0016 * sinf(2 * .pi * (4.3 + Float(voice) * 0.17) * time)
                    let increment = padFrequency[voice] * vibrato / sr
                    advance(&padPhase[voice], increment)
                    let sample = sawWave(phase: padPhase[voice], increment: increment)
                    let (gainL, gainR) = panGains((Float(voice) / 3.5 - 1) * profile.stereoWidth)
                    sumL += sample * gainL
                    sumR += sample * gainR
                }
                let cutoff = 520 + profile.brightness * 1150 + 300 * sinf(2 * .pi * 0.06 * time)
                // Swell into each chord change so the strings breathe instead of sitting flat.
                let swell = attackEnvelope(padAge, attack: 0.55) * (0.62 + 0.38 * expf(-padAge * 0.45))
                padL = padFilterL.lowpass(sumL * 0.12, cutoff: cutoff, resonance: 0.9, sampleRate: sr) * padGain * swell
                padR = padFilterR.lowpass(sumR * 0.12, cutoff: cutoff, resonance: 0.9, sampleRate: sr) * padGain * swell
            }

            var choirL: Float = 0
            var choirR: Float = 0
            if choirGain > 0.002 {
                for voice in 0..<3 {
                    choirFrequency[voice] += (choirTarget[voice] - choirFrequency[voice]) * 0.0022
                    let vibrato = 1 + 0.003 * sinf(2 * .pi * (4.9 + Float(voice) * 0.4) * time + Float(voice))
                    let increment = choirFrequency[voice] * vibrato / sr
                    advance(&choirPhase[voice], increment)
                    let sample = sineWave(phase: choirPhase[voice]) * 0.72
                        + sineWave(phase: fmodf(choirPhase[voice] * 2, 1)) * 0.18
                    let (gainL, gainR) = panGains(Float(voice - 1) * 0.6 * profile.stereoWidth)
                    choirL += sample * gainL
                    choirR += sample * gainR
                }
                let swell = 0.55 + 0.45 * sinf(2 * .pi * 0.045 * time)
                choirL *= choirGain * 0.12 * swell
                choirR *= choirGain * 0.12 * swell
            }

            var guitarL: Float = 0
            var guitarR: Float = 0
            if guitarGain > 0.002, guitarAge < guitarGate + 0.5 {
                let release = guitarAge > guitarGate ? expf(-(guitarAge - guitarGate) * 26) : 1
                let envelope = attackEnvelope(guitarAge, attack: 0.004) * release * expf(-guitarAge * 1.1)
                var trackA: Float = 0
                var trackB: Float = 0
                for voice in 0..<6 {
                    let increment = guitarFrequency[voice] / sr
                    advance(&guitarPhase[voice], increment)
                    let sample = sawWave(phase: guitarPhase[voice], increment: increment)
                    if voice < 3 {
                        trackA += sample
                    } else {
                        trackB += sample
                    }
                }
                let drivenA = overdrive(trackA * 0.42 * envelope, drive: profile.drive)
                let drivenB = overdrive(trackB * 0.42 * envelope, drive: profile.drive)
                let cabA = guitarCabA.process(drivenA)
                let cabB = guitarCabB.process(drivenB)
                let bodyA = cabA - guitarBodyA.process(cabA)
                let bodyB = cabB - guitarBodyB.process(cabB)
                guitarL = (bodyA * 0.82 + bodyB * 0.18) * guitarGain * 0.42
                guitarR = (bodyB * 0.82 + bodyA * 0.18) * guitarGain * 0.42
            }

            var bass: Float = 0
            if bassGain > 0.002, bassAge < 6 {
                let envelope = attackEnvelope(bassAge, attack: 0.006) * expf(-bassAge * (heavy ? 3.2 : 1.1))
                let increment = bassFrequency / sr
                advance(&bassPhase, increment)
                advance(&subPhase, increment * 0.5)
                let body = sawWave(phase: bassPhase, increment: increment) * 0.55
                let sub = sineWave(phase: subPhase) * 0.85
                bass = bassFilter.lowpass((body + sub) * envelope,
                                          cutoff: 160 + profile.brightness * 620,
                                          resonance: 1.1,
                                          sampleRate: sr) * bassGain * 0.4
            }

            var leadL: Float = 0
            var leadR: Float = 0
            if leadGain > 0.002, leadAge < leadGate + 1.8 {
                let increment = (leadAge < leadGraceTime ? leadGraceFrequency : leadFrequency) / sr
                var sample: Float = 0
                var envelope: Float = 0
                switch profile.leadVoice {
                case .violin:
                    let vibrato = 1 + 0.006 * sinf(2 * .pi * 5.4 * time) * min(1, leadAge / 0.25)
                    let inc = increment * vibrato
                    advance(&leadPhaseA, inc)
                    advance(&leadPhaseB, inc * 1.004)
                    sample = (sawWave(phase: leadPhaseA, increment: inc) + sawWave(phase: leadPhaseB, increment: inc)) * 0.5
                    sample = leadFilter.lowpass(sample,
                                                cutoff: 1400 + profile.brightness * 2200,
                                                resonance: 1.0,
                                                sampleRate: sr)
                    envelope = attackEnvelope(leadAge, attack: 0.14)
                        * (leadAge > leadGate ? expf(-(leadAge - leadGate) * 6) : 1)
                case .flute:
                    let inc = increment * (1 + 0.004 * sinf(2 * .pi * 5.0 * time))
                    advance(&leadPhaseA, inc)
                    sample = sineWave(phase: leadPhaseA) * 0.9
                        + triangleWave(phase: leadPhaseA) * 0.1
                        + (rng.nextFloat() * 2 - 1) * 0.03
                    envelope = attackEnvelope(leadAge, attack: 0.07)
                        * (leadAge > leadGate ? expf(-(leadAge - leadGate) * 9) : 1)
                case .bell:
                    advance(&leadPhaseA, increment)
                    advance(&leadPhaseB, increment * 2.76)
                    sample = sineWave(phase: leadPhaseA) * 0.75 + sineWave(phase: leadPhaseB) * 0.25
                    envelope = attackEnvelope(leadAge, attack: 0.005) * expf(-leadAge * 2.2)
                case .brass:
                    advance(&leadPhaseA, increment)
                    advance(&leadPhaseB, increment * 1.006)
                    sample = sawWave(phase: leadPhaseA, increment: increment) * 0.7
                        + squareWave(phase: leadPhaseB, increment: increment) * 0.3
                    sample = leadFilter.lowpass(sample,
                                                cutoff: 900 + 2600 * min(1, leadAge / 0.3) + profile.brightness * 1200,
                                                resonance: 1.3,
                                                sampleRate: sr)
                    envelope = attackEnvelope(leadAge, attack: 0.05)
                        * (leadAge > leadGate ? expf(-(leadAge - leadGate) * 8) : 1)
                case .leadGuitar:
                    let inc = increment * (1 + 0.009 * sinf(2 * .pi * 5.8 * time) * min(1, leadAge / 0.2))
                    advance(&leadPhaseA, inc)
                    sample = overdrive(sawWave(phase: leadPhaseA, increment: inc) * 0.6, drive: profile.drive * 0.9)
                    sample = leadFilter.lowpass(sample,
                                                cutoff: 2400 + profile.brightness * 1800,
                                                resonance: 1.2,
                                                sampleRate: sr)
                    envelope = attackEnvelope(leadAge, attack: 0.012)
                        * (leadAge > leadGate ? expf(-(leadAge - leadGate) * 5) : 1)
                        * expf(-leadAge * 0.35)
                }
                let value = sample * envelope * leadGain * 0.40
                let (gainL, gainR) = panGains(-0.14 * profile.stereoWidth)
                leadL = value * gainL
                leadR = value * gainR
            }

            var harmonyL: Float = 0
            var harmonyR: Float = 0
            if harmonyGain > 0.002, leadAge < leadGate + 1.2 {
                let increment = harmonyFrequency / sr
                advance(&harmonyPhase, increment)
                let raw = heavy
                    ? overdrive(sawWave(phase: harmonyPhase, increment: increment) * 0.5, drive: profile.drive * 0.75)
                    : sawWave(phase: harmonyPhase, increment: increment) * 0.45 + sineWave(phase: harmonyPhase) * 0.5
                let shaped = harmonyFilter.lowpass(raw,
                                                   cutoff: 1100 + profile.brightness * 1500,
                                                   resonance: 0.85,
                                                   sampleRate: sr)
                let envelope = attackEnvelope(leadAge, attack: 0.1)
                    * (leadAge > leadGate ? expf(-(leadAge - leadGate) * 7) : 1)
                let value = shaped * envelope * harmonyGain * 0.30
                let (gainL, gainR) = panGains(0.34 * profile.stereoWidth)
                harmonyL = value * gainL
                harmonyR = value * gainR
            }

            var arpL: Float = 0
            var arpR: Float = 0
            if arpGain > 0.002, arpAge < 3 {
                let increment = arpFrequency / sr
                advance(&arpPhase, increment)
                let sample: Float
                let envelope: Float
                switch profile.arpVoice {
                case .harp:
                    sample = triangleWave(phase: arpPhase) * 0.7 + sineWave(phase: arpPhase) * 0.3
                    envelope = attackEnvelope(arpAge, attack: 0.004) * expf(-arpAge * 3.4)
                case .glass:
                    sample = sineWave(phase: arpPhase) * 0.8 + sineWave(phase: fmodf(arpPhase * 3.01, 1)) * 0.2
                    envelope = attackEnvelope(arpAge, attack: 0.006) * expf(-arpAge * 1.8)
                case .pluck:
                    sample = sawWave(phase: arpPhase, increment: increment) * 0.55
                    envelope = attackEnvelope(arpAge, attack: 0.003) * expf(-arpAge * 6)
                case .palmMute:
                    sample = overdrive(sawWave(phase: arpPhase, increment: increment) * 0.5, drive: profile.drive * 0.6)
                    envelope = attackEnvelope(arpAge, attack: 0.002) * expf(-arpAge * 14)
                }
                let value = sample * envelope * arpGain * 0.26
                let (gainL, gainR) = panGains(arpPan * profile.stereoWidth)
                arpL = value * gainL
                arpR = value * gainR
            }

            var drumL: Float = 0
            var drumR: Float = 0
            if drumGain > 0.002 {
                if kickAge < 1.4, kickVelocity > 0 {
                    let tune: Float
                    let decay: Float
                    switch profile.percussion {
                    case .orchestral: tune = 62; decay = 3.2
                    case .cinematic: tune = 52; decay = 6.5
                    case .rockKit: tune = 48; decay = 8.5
                    case .metalKit: tune = 46; decay = 11.0
                    }
                    let sweep = tune * (kickAge + 3.4 * (1 - expf(-kickAge * 44)) / 44)
                    let click = profile.percussion == .orchestral ? 0 : expf(-kickAge * 340) * 0.55
                    let kick = (sinf(2 * .pi * sweep) * expf(-kickAge * decay) + click) * kickVelocity
                    drumL += kick
                    drumR += kick
                }
                if snareAge < 0.7, snareVelocity > 0 {
                    let raw = rng.nextFloat() * 2 - 1
                    let low = snareLow.process(raw)
                    let band = low - snareHigh.process(low)
                    let tone = sinf(2 * .pi * 190 * snareAge) * 0.5 + sinf(2 * .pi * 336 * snareAge) * 0.32
                    let snare = (band * 1.1 + tone * expf(-snareAge * 22)) * expf(-snareAge * 13) * snareVelocity * 0.6
                    drumL += snare
                    drumR += snare
                }
                if hatAge < 0.45, hatVelocity > 0 {
                    let raw = rng.nextFloat() * 2 - 1
                    let hat = (raw - hatFilter.process(raw)) * expf(-hatAge * 46) * hatVelocity * 0.3
                    let (gainL, gainR) = panGains(0.35 * profile.stereoWidth)
                    drumL += hat * gainL
                    drumR += hat * gainR
                }
                if crashAge < 2.8 {
                    let rawL = rng.nextFloat() * 2 - 1
                    let rawR = rng.nextFloat() * 2 - 1
                    let envelope: Float = profile.percussion == .orchestral
                        ? min(1, crashAge / 1.4) * expf(-max(0, crashAge - 1.4) * 2.4) * 0.14
                        : expf(-crashAge * 2.1) * 0.2
                    drumL += (rawL - crashFilter.process(rawL)) * envelope
                    drumR += (rawR - crashFilterR.process(rawR)) * envelope
                }
                drumL *= drumGain * 0.85
                drumR *= drumGain * 0.85
            }

            let dryL = padL + choirL + guitarL + leadL + harmonyL + arpL + bass * 0.75 + drumL
            let dryR = padR + choirR + guitarR + leadR + harmonyR + arpR + bass * 0.75 + drumR

            let (delayL, delayR) = delay.process((leadL + harmonyL + arpL) * profile.delayMix,
                                                 (leadR + harmonyR + arpR) * profile.delayMix)
            let wetL = reverbL.process((dryL + delayL) * profile.reverbMix)
            let wetR = reverbR.process((dryR + delayR) * profile.reverbMix)

            var mixL = dcBlockerL.process(dryL + delayL * 0.7 + wetL)
            var mixR = dcBlockerR.process(dryR + delayR * 0.7 + wetR)

            let mid = (mixL + mixR) * 0.5
            let side = (mixL - mixR) * 0.5 * (1 + profile.stereoWidth * 0.5)
            mixL = mid + side
            mixR = mid - side

            let fade = min(1, time / 1.2) * min(1, max(0, (totalSeconds - time) / 2.2))
            let gain = limiter.gain(forPeak: max(abs(mixL), abs(mixR)))
            let finalL = tanhf(mixL * gain * 1.1) * fade
            let finalR = tanhf(mixR * gain * 1.1) * fade
            outputL[frame] = finalL
            outputR[frame] = finalR

            let bucket = min(waveformBuckets - 1, frame * waveformBuckets / totalFrames)
            let level = Double((abs(finalL) + abs(finalR)) * 0.5)
            waveformSums[bucket] += level * level
            waveformCounts[bucket] += 1
        }

        try file.write(from: buffer)

        var peak = 0.0
        let levels = zip(waveformSums, waveformCounts).map { sum, count -> Double in
            let value = count > 0 ? (sum / Double(count)).squareRoot() : 0
            peak = max(peak, value)
            return value
        }
        let normalizer = peak > 0.0001 ? 1 / peak : 1
        return levels.map { min(1, max(0.05, $0 * normalizer)) }
    }
}

// MARK: - DSP primitives

/// PolyBLEP correction removes the aliasing "buzz" from naive saw/square oscillators.
@inline(__always)
private func polyBlep(_ phase: Float, _ increment: Float) -> Float {
    guard increment > 0 else { return 0 }
    if phase < increment {
        let t = phase / increment
        return t + t - t * t - 1
    }
    if phase > 1 - increment {
        let t = (phase - 1) / increment
        return t * t + t + t + 1
    }
    return 0
}

@inline(__always)
private func sawWave(phase: Float, increment: Float) -> Float {
    (2 * phase - 1) - polyBlep(phase, increment)
}

@inline(__always)
private func squareWave(phase: Float, increment: Float) -> Float {
    var value: Float = phase < 0.5 ? 1 : -1
    value += polyBlep(phase, increment)
    var shifted = phase - 0.5
    if shifted < 0 { shifted += 1 }
    value -= polyBlep(shifted, increment)
    return value
}

@inline(__always)
private func sineWave(phase: Float) -> Float {
    sinf(phase * 2 * .pi)
}

@inline(__always)
private func triangleWave(phase: Float) -> Float {
    4 * abs(phase - 0.5) - 1
}

@inline(__always)
private func advance(_ phase: inout Float, _ increment: Float) {
    phase += increment
    if phase >= 1 { phase -= floorf(phase) }
}

/// Equal-power pan, `-1` hard left … `1` hard right.
@inline(__always)
private func panGains(_ pan: Float) -> (Float, Float) {
    let clamped = min(max(pan, -1), 1)
    let angle = (clamped + 1) * 0.25 * Float.pi
    return (cosf(angle), sinf(angle))
}

@inline(__always)
private func overdrive(_ input: Float, drive: Float) -> Float {
    let gain = 1 + drive * 34
    return tanhf(input * gain) / (1 + drive * 2.2)
}

@inline(__always)
private func attackEnvelope(_ age: Float, attack: Float) -> Float {
    attack <= 0 ? 1 : min(1, age / attack)
}

private struct StateVariableFilter {
    private var low: Float = 0
    private var band: Float = 0

    mutating func lowpass(_ input: Float, cutoff: Float, resonance: Float, sampleRate: Float) -> Float {
        let safeCutoff = min(max(cutoff, 25), sampleRate * 0.16)
        let f = 2 * sinf(.pi * safeCutoff / sampleRate)
        let damping = 1 / max(resonance, 0.55)
        let high = input - low - damping * band
        band = min(max(band + f * high, -8), 8)
        low = min(max(low + f * band, -8), 8)
        return low
    }
}

private struct DCBlocker {
    private var lastInput: Float = 0
    private var lastOutput: Float = 0

    mutating func process(_ input: Float) -> Float {
        let output = input - lastInput + 0.9975 * lastOutput
        lastInput = input
        lastOutput = output
        return output
    }
}

private struct CombFilter {
    private var buffer: [Float]
    private var index = 0
    private var store: Float = 0
    private let feedback: Float
    private let damping: Float

    init(size: Int, feedback: Float, damping: Float) {
        buffer = Array(repeating: 0, count: max(1, size))
        self.feedback = feedback
        self.damping = damping
    }

    mutating func process(_ input: Float) -> Float {
        let output = buffer[index]
        store = output * (1 - damping) + store * damping
        buffer[index] = input + store * feedback
        index += 1
        if index >= buffer.count { index = 0 }
        return output
    }
}

private struct AllPassFilter {
    private var buffer: [Float]
    private var index = 0
    private let feedback: Float

    init(size: Int, feedback: Float) {
        buffer = Array(repeating: 0, count: max(1, size))
        self.feedback = feedback
    }

    mutating func process(_ input: Float) -> Float {
        let buffered = buffer[index]
        let output = -input + buffered
        buffer[index] = input + buffered * feedback
        index += 1
        if index >= buffer.count { index = 0 }
        return output
    }
}

/// Freeverb-style hall, one instance per channel with an offset for stereo decorrelation.
private struct ReverbChannel {
    private var combs: [CombFilter]
    private var allpasses: [AllPassFilter]

    init(offset: Int, roomSize: Float, damping: Float) {
        let combTunings = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        let allpassTunings = [556, 441, 341, 225]
        combs = combTunings.map { CombFilter(size: $0 + offset, feedback: min(roomSize, 0.96), damping: damping) }
        allpasses = allpassTunings.map { AllPassFilter(size: $0 + offset, feedback: 0.5) }
    }

    mutating func process(_ input: Float) -> Float {
        var output: Float = 0
        for index in combs.indices {
            output += combs[index].process(input)
        }
        output *= 0.12
        for index in allpasses.indices {
            output = allpasses[index].process(output)
        }
        return output
    }
}

private struct PingPongDelay {
    private var bufferL: [Float]
    private var bufferR: [Float]
    private var index = 0
    private let feedback: Float

    init(sampleRate: Float, time: Float, feedback: Float) {
        let length = max(1, Int(sampleRate * max(time, 0.02)))
        bufferL = Array(repeating: 0, count: length)
        bufferR = Array(repeating: 0, count: length)
        self.feedback = feedback
    }

    mutating func process(_ inputL: Float, _ inputR: Float) -> (Float, Float) {
        let outputL = bufferL[index]
        let outputR = bufferR[index]
        bufferL[index] = inputL + outputR * feedback
        bufferR[index] = inputR + outputL * feedback
        index += 1
        if index >= bufferL.count { index = 0 }
        return (outputL, outputR)
    }
}

private struct Limiter {
    private var envelope: Float = 0
    private let threshold: Float

    init(threshold: Float) {
        self.threshold = threshold
    }

    mutating func gain(forPeak peak: Float) -> Float {
        let coefficient: Float = peak > envelope ? 0.35 : 0.00008
        envelope += (peak - envelope) * coefficient
        return envelope > threshold ? threshold / envelope : 1
    }
}

private struct OnePoleFilter {
    private var value: Float = 0
    private let coefficient: Float

    init(cutoffHz: Float, sampleRate: Float) {
        coefficient = min(1, 1 - expf(-2 * .pi * max(cutoffHz, 1) / max(sampleRate, 1)))
    }

    mutating func process(_ input: Float) -> Float {
        value += coefficient * (input - value)
        return value
    }
}

struct DreamRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x123456789ABCDEF : seed
    }

    mutating func nextFloat() -> Float {
        state = state &* 6364136223846793005 &+ 1
        return Float(UInt32(truncatingIfNeeded: state >> 32)) / Float(UInt32.max)
    }
}

func makeSeed(from uuid: UUID) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    withUnsafeBytes(of: uuid.uuid) { bytes in
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
    }
    return hash
}