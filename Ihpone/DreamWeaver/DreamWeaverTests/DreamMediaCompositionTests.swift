import AVFoundation
import Foundation
import SwiftUI
import Testing
@testable import DreamWeaver

@Suite("End-to-end AI dream media", .serialized)
struct DreamMediaCompositionTests {

    @Test("A dream without a REM profile cannot be composed")
    func missingProfileThrows() async {
        var dream = DreamFixture.dream(mood: .peaceful)
        dream.remProfile = nil

        await #expect(throws: DreamMediaComposer.ComposerError.self) {
            _ = try await DreamMediaComposer.shared.composeMedia(for: dream)
        }
    }

    /// A full compose renders a minute of audio and well over a thousand frames, so the whole
    /// pipeline is exercised once and every invariant is checked against that single result.
    @Test("A full compose produces synchronised, playable film and score", .timeLimit(.minutes(5)))
    func composesCompleteResult() async throws {
        let dream = DreamFixture.dream(mood: .ethereal, segmentCount: 3)
        var progressValues: [Double] = []

        let result = try await DreamMediaComposer.shared.composeMedia(for: dream) { progress in
            progressValues.append(progress)
        }

        // Presentation
        #expect(result.headline.contains(dream.mood.displayName))
        #expect(!result.soundtrackMood.isEmpty)
        #expect(!result.previewText.isEmpty)
        #expect(result.runtime > 0 && result.runtime <= 60)
        #expect(result.waveform.count == 80)
        #expect(result.waveform.allSatisfy { $0 >= 0 && $0 <= 1 })

        // Progress reporting
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
        #expect(progressValues.allSatisfy { $0 >= 0 && $0 <= 1 })

        // Files exist
        let videoURL = try #require(result.videoURL)
        let audioURL = try #require(result.audioURL)
        #expect(FileManager.default.fileExists(atPath: videoURL.path))
        #expect(FileManager.default.fileExists(atPath: audioURL.path))

        // The score is stereo
        let audioFile = try AVAudioFile(forReading: audioURL)
        #expect(audioFile.fileFormat.channelCount == 2)

        // Film and score share a bar-aligned runtime so they loop together
        let videoSeconds = CMTimeGetSeconds(try await AVURLAsset(url: videoURL).load(.duration))
        let audioSeconds = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        #expect(abs(videoSeconds - audioSeconds) < 0.5,
                "film \(videoSeconds)s vs score \(audioSeconds)s")
        #expect(abs(result.runtime - audioSeconds) < 0.5)

        // The film is rendered at full resolution
        let track = try #require(try await AVURLAsset(url: videoURL).loadTracks(withMediaType: .video).first)
        let dimensions = try await track.load(.naturalSize)
        #expect(Int(dimensions.width) == DreamFilmRenderer.width)
        #expect(Int(dimensions.height) == DreamFilmRenderer.height)

        // Diagnostics merge the score and film reports
        #expect(result.diagnostics["genre"]?.isEmpty == false)
        #expect(result.diagnostics["visualStyle"]?.isEmpty == false)
        #expect(result.diagnostics["channels"] == "stereo")
        #expect(result.diagnostics["resolution"]?.isEmpty == false)
        #expect(result.diagnostics["intensity"]?.isEmpty == false)
        #expect(result.diagnostics["apneaSpikes"]?.isEmpty == false)

        // Scenes describe each REM segment in order
        #expect(result.scenes.count == dream.remProfile?.segments.count)
        for scene in result.scenes {
            #expect(!scene.title.isEmpty)
            #expect(!scene.subtitle.isEmpty)
            #expect(!scene.symbol.isEmpty)
            #expect(scene.duration > 0)
            #expect(scene.startOffset >= 0)
            #expect(scene.remSegmentId != nil)
        }
        let offsets = result.scenes.map(\.startOffset)
        #expect(offsets == offsets.sorted())
    }
}

@Suite("Dream models and chart data")
struct DreamModelTests {

    @Test("Every mood has artwork and a display name", arguments: DreamMood.allCases)
    func moodPresentation(mood: DreamMood) {
        #expect(!mood.displayName.isEmpty)
        #expect(!mood.icon.isEmpty)
        #expect(mood.colors.count >= 2)
        #expect(mood.id == mood.rawValue)
    }

    @Test("Moods survive a coding round trip", arguments: DreamMood.allCases)
    func moodCodable(mood: DreamMood) throws {
        let data = try JSONEncoder().encode(mood)
        #expect(try JSONDecoder().decode(DreamMood.self, from: data) == mood)
    }

    @Test("A dream survives a coding round trip")
    func dreamCodable() throws {
        let dream = DreamFixture.dream(mood: .intense)
        let data = try JSONEncoder().encode(dream)
        let decoded = try JSONDecoder().decode(SleepData.self, from: data)

        #expect(decoded.id == dream.id)
        #expect(decoded.mood == dream.mood)
        #expect(decoded.biosignals.count == dream.biosignals.count)
        #expect(decoded.remProfile?.segments.count == dream.remProfile?.segments.count)
        #expect(decoded.duration == dream.duration)
    }

    @Test("Dream duration is derived from the timestamps")
    func dreamDuration() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let dream = DreamFixture.dream(mood: .calm, startedAt: start)
        #expect(dream.duration == 4 * 3600)
        #expect(dream.endedAt > dream.startedAt)
    }

    @Test("A REM profile survives a coding round trip")
    func remProfileCodable() throws {
        let profile = try #require(DreamFixture.dream(mood: .turbulent).remProfile)
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(REMDreamProfile.self, from: data)

        #expect(decoded.segments.count == profile.segments.count)
        #expect(decoded.heartRateTrend == profile.heartRateTrend)
        #expect(decoded.apneaSpikeCount == profile.apneaSpikeCount)
    }

    @Test("Every REM driver has a stable raw value", arguments: [
        REMDriver.heartRate, .hrv, .apnea, .noise, .temperature, .unknown
    ])
    func driverRawValues(driver: REMDriver) throws {
        #expect(!driver.rawValue.isEmpty)
        #expect(REMDriver(rawValue: driver.rawValue) == driver)
    }

    // MARK: - Chart data

    @Test("Chart curves read the metric they were built for")
    func chartCurveReadsKeyPath() {
        let sample = DreamFixture.biosignals(from: Date(), count: 1)[0]
        let heart = MultiMetricChart.MetricCurve(label: "HR", keyPath: \.heartRate, color: .red)
        let hrv = MultiMetricChart.MetricCurve(label: "HRV", keyPath: \.hrv, color: .blue)

        #expect(heart.value(for: sample) == sample.heartRate)
        #expect(hrv.value(for: sample) == sample.hrv)
        #expect(heart.label == "HR")
    }

    @Test("Chart curves accept a computed provider")
    func chartCurveComputedValue() {
        let sample = DreamFixture.biosignals(from: Date(), count: 1)[0]
        let curve = MultiMetricChart.MetricCurve(label: "Load", color: .green) {
            $0.heartRate / max($0.hrv, 1)
        }

        #expect(curve.value(for: sample) == sample.heartRate / sample.hrv)
    }

    @Test("Every plotted metric yields finite values for the whole series")
    func chartMetricsAreFinite() {
        let samples = DreamFixture.biosignals(from: Date(), count: 120)
        let curves: [MultiMetricChart.MetricCurve] = [
            .init(label: "HR", keyPath: \.heartRate, color: .red),
            .init(label: "HRV", keyPath: \.hrv, color: .blue),
            .init(label: "SpO2", keyPath: \.spo2, color: .teal),
            .init(label: "Respiration", keyPath: \.respiratoryRate, color: .mint),
            .init(label: "Movement", keyPath: \.movement, color: .orange),
            .init(label: "Noise", keyPath: \.noiseExposure, color: .gray),
            .init(label: "Apnea", keyPath: \.apneaRisk, color: .pink),
            .init(label: "Temperature", keyPath: \.wristTemperatureDelta, color: .purple),
            .init(label: "Sleep score", keyPath: \.sleepScore, color: .indigo)
        ]

        for curve in curves {
            for sample in samples {
                let value = curve.value(for: sample)
                #expect(value.isFinite, "\(curve.label) produced a non-finite value")
            }
        }
    }

    @Test("Biosignal samples are chronological")
    func samplesAreChronological() {
        let samples = DreamFixture.biosignals(from: Date(timeIntervalSince1970: 0), count: 50)
        for pair in zip(samples, samples.dropFirst()) {
            #expect(pair.1.timestamp > pair.0.timestamp)
        }
    }

    @Test("The seeded generator is deterministic and covers the full range")
    func randomGeneratorBehaviour() {
        var first = DreamRandom(seed: 42)
        var second = DreamRandom(seed: 42)
        var low = false
        var high = false

        for _ in 0..<5_000 {
            let a = first.nextFloat()
            let b = second.nextFloat()
            #expect(a == b)
            #expect(a >= 0 && a <= 1)
            if a < 0.25 { low = true }
            if a > 0.75 { high = true }
        }

        #expect(low && high, "the generator never reaches both ends of the range")
    }

    @Test("Seeds are stable per dream and unique across dreams")
    func seedsAreStable() {
        let id = UUID()
        #expect(makeSeed(from: id) == makeSeed(from: id))
        #expect(makeSeed(from: UUID()) != makeSeed(from: UUID()))
    }
}
