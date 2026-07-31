import AVFoundation
import Foundation
import Testing
@testable import DreamWeaver

@Suite("Dream score generation")
struct DreamScoreTests {

    // MARK: - Genre selection

    @Test("Every mood maps to a genre", arguments: DreamMood.allCases)
    func moodMapsToGenre(mood: DreamMood) {
        let calm = DreamGenre.make(mood: mood, intensity: 0.2)
        let wild = DreamGenre.make(mood: mood, intensity: 0.95)
        #expect(!calm.soundtrackLabel.isEmpty)
        #expect(!wild.soundtrackLabel.isEmpty)
    }

    @Test("Peaceful dreams are symphonic and turbulent dreams are heavy")
    func moodExtremes() {
        #expect(DreamGenre.make(mood: .peaceful, intensity: 0.5) == .symphonic)
        #expect(DreamGenre.make(mood: .turbulent, intensity: 0.5) == .hardRock)
        #expect(DreamGenre.make(mood: .chaotic, intensity: 0.5) == .industrial)
        #expect(DreamGenre.make(mood: .ethereal, intensity: 0.5) == .celestial)
    }

    @Test("Intensity escalates an intense dream from cinematic to hard rock")
    func intensityEscalates() {
        #expect(DreamGenre.make(mood: .intense, intensity: 0.2) == .cinematic)
        #expect(DreamGenre.make(mood: .intense, intensity: 0.9) == .hardRock)
    }

    // MARK: - Score profile invariants

    @Test("Score profiles are well formed for every mood", arguments: DreamMood.allCases)
    func profileIsWellFormed(mood: DreamMood) throws {
        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))

        #expect(profile.tempo >= 40 && profile.tempo <= 180)
        #expect(profile.beatsPerBar == 4)
        #expect(profile.barsPerChord >= 1)
        #expect(profile.tonicHz > 30 && profile.tonicHz < 400)
        #expect(profile.scale.count == 7)
        #expect(profile.scale.first == 0)
        #expect(!profile.progression.isEmpty)
        #expect(profile.riff.count == 16)
        #expect(profile.bassPattern.count == 16)
        #expect(profile.kickPattern.count == 16)
        #expect(profile.snarePattern.count == 16)
        #expect(profile.hatPattern.count == 16)
        #expect(profile.ornamentChance >= 0 && profile.ornamentChance <= 1)
    }

    @Test("Scales are strictly ascending inside one octave", arguments: DreamMood.allCases)
    func scalesAreAscending(mood: DreamMood) throws {
        let scale = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood)).scale
        for pair in zip(scale, scale.dropFirst()) {
            #expect(pair.1 > pair.0)
        }
        #expect(scale.last! < 12)
    }

    @Test("Chord degrees stay inside the scale", arguments: DreamMood.allCases)
    func progressionStaysInScale(mood: DreamMood) throws {
        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))
        for degree in profile.progression {
            #expect(degree >= 0 && degree < profile.scale.count)
        }
    }

    /// The renderer restarts the phrase every four bars, so each phrase must fill exactly 64 steps.
    @Test("Every melodic phrase is exactly four bars", arguments: DreamMood.allCases)
    func phrasesAreFourBars(mood: DreamMood) throws {
        for intensity in [0.15, 0.5, 0.95] {
            let profile = try DreamFixture.scoreProfile(
                for: DreamFixture.dream(mood: mood, intensity: intensity)
            )
            #expect(!profile.melodyPhrases.isEmpty)
            for phrase in profile.melodyPhrases {
                let steps = phrase.reduce(0) { $0 + $1.steps }
                #expect(steps == 64, "\(mood) at \(intensity) produced a \(steps)-step phrase")
                #expect(phrase.allSatisfy { $0.steps > 0 })
            }
        }
    }

    @Test("Melody uses several phrases so the tune does not loop every bar", arguments: DreamMood.allCases)
    func melodyHasMultiplePhrases(mood: DreamMood) throws {
        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))
        #expect(profile.melodyPhrases.count >= 2)
    }

    @Test("Calm and restless dreams of the same mood get different melodies",
          arguments: DreamMood.allCases)
    func intensityChangesMelody(mood: DreamMood) throws {
        let calm = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood,
                                                                         intensity: 0.1,
                                                                         polarity: 0.1))
        let restless = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood,
                                                                            intensity: 0.9,
                                                                            polarity: 0.1))
        let calmShape = calm.melodyPhrases.map { $0.map(\.steps) }
        let restlessShape = restless.melodyPhrases.map { $0.map(\.steps) }
        #expect(calmShape != restlessShape)
    }

    @Test("Different moods produce different melodic material")
    func moodsDifferFromEachOther() throws {
        var shapes: [String: [[Int]]] = [:]
        for mood in DreamMood.allCases {
            let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))
            shapes[mood.rawValue] = profile.melodyPhrases.map { $0.map { $0.degree ?? -99 } }
        }
        // Peaceful, ethereal and chaotic must not share a tune.
        #expect(shapes["peaceful"] != shapes["ethereal"])
        #expect(shapes["ethereal"] != shapes["chaotic"])
        #expect(shapes["peaceful"] != shapes["chaotic"])
    }

    @Test("Heavy genres drive harder and reverberate less")
    func heavyGenresAreDrier() throws {
        let peaceful = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: .peaceful))
        let turbulent = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: .turbulent))

        #expect(turbulent.drive > peaceful.drive)
        #expect(turbulent.reverbMix < peaceful.reverbMix)
        #expect(turbulent.tempo > peaceful.tempo)
        #expect(turbulent.gains.guitar > 0)
        #expect(peaceful.gains.guitar == 0)
    }

    @Test("The lead is mixed above the pad so the melody carries", arguments: DreamMood.allCases)
    func leadDominatesPad(mood: DreamMood) throws {
        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))
        #expect(profile.gains.lead > profile.gains.pad)
        #expect(profile.gains.lead > profile.gains.choir)
        #expect(profile.harmonyAmount >= 0 && profile.harmonyAmount <= 1)
    }

    @Test("A faster heart rate raises the tempo")
    func heartRateDrivesTempo() throws {
        let slow = DreamFixture.dream(mood: .peaceful)
        var fast = slow
        fast.remProfile = REMDreamProfile(
            totalDuration: 1800,
            intensityScore: 0.45,
            moodPolarity: 0.4,
            heartRateTrend: .rising,
            hrvTrend: .falling,
            apneaSpikeCount: 1,
            noiseSpikeCount: 0,
            segments: slow.remProfile!.segments.map {
                REMSegment(id: $0.id, start: $0.start, end: $0.end,
                           dominantDriver: $0.dominantDriver,
                           heartRateAvg: 95, hrvAvg: $0.hrvAvg,
                           intensity: $0.intensity, moodPolarity: $0.moodPolarity)
            }
        )

        let slowTempo = try DreamFixture.scoreProfile(for: slow).tempo
        let fastTempo = try DreamFixture.scoreProfile(for: fast).tempo
        #expect(fastTempo > slowTempo)
    }

    // MARK: - Determinism

    @Test("The same dream always renders the same score")
    func profileIsDeterministic() throws {
        let dream = DreamFixture.dream(mood: .calm)
        let first = try DreamFixture.scoreProfile(for: dream)
        let second = try DreamFixture.scoreProfile(for: dream)

        #expect(first.seed == second.seed)
        #expect(first.tempo == second.tempo)
        #expect(first.tonicHz == second.tonicHz)
        #expect(first.progression == second.progression)
    }

    @Test("Two different dreams get different seeds")
    func differentDreamsDiffer() throws {
        let first = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: .calm))
        let second = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: .calm))
        #expect(first.seed != second.seed)
    }

    // MARK: - Duration alignment

    @Test("Runtime is snapped to whole bars", arguments: DreamMood.allCases)
    func durationIsBarAligned(mood: DreamMood) throws {
        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))
        let duration = profile.alignedDuration(target: 2400)
        let secondsPerBar = Double(profile.beatsPerBar) * 60 / Double(profile.tempo)
        let bars = duration / secondsPerBar

        #expect(abs(bars.rounded() - bars) < 0.001)
        #expect(duration > 0 && duration <= 60)
    }

    @Test("Very short and very long sessions are clamped into range", arguments: DreamMood.allCases)
    func durationIsClamped(mood: DreamMood) throws {
        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))
        #expect(profile.alignedDuration(target: 1) > 0)
        #expect(profile.alignedDuration(target: 100_000) <= 60)
    }

    // MARK: - Audio rendering

    @Test("The score renders a playable stereo file for every mood", arguments: DreamMood.allCases)
    func rendersStereoAudio(mood: DreamMood) throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))
        let url = directory.appendingPathComponent("score-\(mood.rawValue).caf")
        let waveform = try DreamScoreRenderer.render(to: url, profile: profile, duration: 2)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.channelCount == 2, "\(mood) score is not stereo")
        #expect(file.fileFormat.sampleRate == 44_100)
        #expect(file.length > 0)
        #expect(waveform.count == 80)
    }

    @Test("The waveform is normalised and finite", arguments: DreamMood.allCases)
    func waveformIsNormalised(mood: DreamMood) throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood))
        let waveform = try DreamScoreRenderer.render(
            to: directory.appendingPathComponent("wave.caf"),
            profile: profile,
            duration: 3
        )

        #expect(waveform.allSatisfy { $0.isFinite })
        #expect(waveform.allSatisfy { $0 >= 0 && $0 <= 1 })
        #expect(waveform.contains { $0 > 0.5 }, "\(mood) never reaches a strong level")
    }

    @Test("Rendered audio is audible and never clips")
    func audioIsAudibleAndClean() throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: .peaceful))
        let url = directory.appendingPathComponent("levels.caf")
        _ = try DreamScoreRenderer.render(to: url, profile: profile, duration: 4)

        let file = try AVAudioFile(forReading: url)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                   frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channels = try #require(buffer.floatChannelData)
        let frames = Int(buffer.frameLength)
        #expect(frames > 0)

        var peak: Float = 0
        var energy: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<frames {
                let sample = channels[channel][frame]
                #expect(sample.isFinite)
                peak = max(peak, abs(sample))
                energy += sample * sample
            }
        }

        #expect(peak > 0.05, "the score is effectively silent")
        #expect(peak <= 1.0, "the score clips")
        #expect(energy > 0)
    }

    @Test("The two channels differ, so the image is truly stereo")
    func channelsAreDecorrelated() throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: .ethereal))
        let url = directory.appendingPathComponent("stereo.caf")
        _ = try DreamScoreRenderer.render(to: url, profile: profile, duration: 4)

        let file = try AVAudioFile(forReading: url)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                   frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channels = try #require(buffer.floatChannelData)

        var difference: Float = 0
        for frame in 0..<Int(buffer.frameLength) {
            difference += abs(channels[0][frame] - channels[1][frame])
        }
        #expect(difference > 0, "left and right are identical")
    }

    @Test("Re-rendering the same dream produces identical audio")
    func renderingIsReproducible() throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: .calm))
        let first = try DreamScoreRenderer.render(
            to: directory.appendingPathComponent("a.caf"), profile: profile, duration: 2)
        let second = try DreamScoreRenderer.render(
            to: directory.appendingPathComponent("b.caf"), profile: profile, duration: 2)

        #expect(first == second)
    }

    @Test("Diagnostics describe the generated score", arguments: DreamMood.allCases)
    func diagnosticsAreReported(mood: DreamMood) throws {
        let diagnostics = try DreamFixture.scoreProfile(for: DreamFixture.dream(mood: mood)).diagnostics
        #expect(diagnostics["channels"] == "stereo")
        #expect(diagnostics["genre"]?.isEmpty == false)
        #expect(diagnostics["tempo"]?.contains("BPM") == true)
        #expect(diagnostics["key"]?.contains("Hz") == true)
    }
}
