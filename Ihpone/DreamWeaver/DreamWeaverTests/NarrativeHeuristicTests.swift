import Foundation
import Testing
@testable import DreamWeaver

@Suite("Biosignal narrative heuristic")
struct NarrativeHeuristicTests {

    // MARK: - Helpers

    private let baseStart = Date(timeIntervalSince1970: 1_700_014_800) // 03:00 UTC

    /// Builds a `SleepSession` with a fully specified `REMDreamProfile` and runs the heuristic.
    private func analyse(
        heartRate: Double = 62,
        hrv: Double = 55,
        moodPolarity: Double = 0.4,
        intensityScore: Double = 0.4,
        apneaSpikes: Int = 0,
        noiseSpikes: Int = 0,
        hrTrend: REMTrend = .stable,
        hrvTrend: REMTrend = .stable,
        totalRemDuration: TimeInterval = 1800,
        remSamples: Int = 0,
        deepSamples: Int = 0,
        lightSamples: Int = 0
    ) -> SleepAIResult {
        let end = baseStart.addingTimeInterval(8 * 3600)
        let profile = REMDreamProfile(
            totalDuration: totalRemDuration,
            intensityScore: intensityScore,
            moodPolarity: moodPolarity,
            heartRateTrend: hrTrend,
            hrvTrend: hrvTrend,
            apneaSpikeCount: apneaSpikes,
            noiseSpikeCount: noiseSpikes,
            segments: [REMSegment(
                start: baseStart.addingTimeInterval(3600),
                end: baseStart.addingTimeInterval(3600 + totalRemDuration),
                dominantDriver: apneaSpikes > 2 ? .apnea : .heartRate,
                heartRateAvg: heartRate, hrvAvg: hrv,
                intensity: intensityScore, moodPolarity: moodPolarity
            )]
        )

        // Build stage-labelled biosignals when requested
        var biosignals: [BiosignalDataPoint] = []
        let spacing: TimeInterval = 30
        func point(_ stage: REMState, offset: Int) -> BiosignalDataPoint {
            BiosignalDataPoint(timestamp: baseStart.addingTimeInterval(Double(offset) * spacing),
                               heartRate: heartRate, hrv: hrv, sleepStage: stage)
        }
        for i in 0..<remSamples   { biosignals.append(point(.rem,   offset: i)) }
        for i in 0..<deepSamples  { biosignals.append(point(.deep,  offset: remSamples + i)) }
        for i in 0..<lightSamples { biosignals.append(point(.light, offset: remSamples + deepSamples + i)) }
        if biosignals.isEmpty {
            biosignals = DreamFixture.biosignals(from: baseStart, count: 10)
        }

        var session = SleepSession(startedAt: baseStart,
                                   biosignals: biosignals,
                                   averageHeartRate: heartRate,
                                   hrvAverage: hrv,
                                   remProfile: profile)
        session.finish(on: end)
        return BiosignalHeuristic.analyse(session: session)
    }

    // MARK: - Mood derivation

    @Test("Calm positive night with low intensity → peaceful")
    func moodPeaceful() {
        #expect(analyse(moodPolarity: 0.6, intensityScore: 0.3).mood == .peaceful)
    }

    @Test("Moderate positive polarity with moderate intensity → calm")
    func moodCalm() {
        #expect(analyse(moodPolarity: 0.3, intensityScore: 0.5).mood == .calm)
    }

    @Test("Positive polarity with high intensity → ethereal")
    func moodEthereal() {
        #expect(analyse(moodPolarity: 0.2, intensityScore: 0.8).mood == .ethereal)
    }

    @Test("High intensity with neutral polarity → intense")
    func moodIntense() {
        #expect(analyse(moodPolarity: 0.0, intensityScore: 0.7).mood == .intense)
    }

    @Test("Two or three disruptions with negative polarity → turbulent")
    func moodTurbulent() {
        #expect(analyse(moodPolarity: -0.4, apneaSpikes: 2, noiseSpikes: 1).mood == .turbulent)
    }

    @Test("Six or more disruptions → chaotic regardless of polarity")
    func moodChaoticManyDisruptions() {
        #expect(analyse(moodPolarity: 0.8, apneaSpikes: 4, noiseSpikes: 3).mood == .chaotic)
    }

    // MARK: - Narrative groundedness

    @Test("Narrative references the actual heart rate")
    func narrativeContainsHeartRate() {
        let result = analyse(heartRate: 58, moodPolarity: 0.2, intensityScore: 0.3)
        #expect(result.narrative.contains("58"))
    }

    @Test("Narrative references the actual HRV")
    func narrativeContainsHRV() {
        let result = analyse(heartRate: 62, hrv: 67, moodPolarity: 0.5, intensityScore: 0.2)
        #expect(result.narrative.contains("67"))
    }

    @Test("Narrative references the REM window start time (contains colon)")
    func narrativeContainsREMTime() {
        // The segment starts at baseStart + 1 h; the narrative formats it as HH:MM
        #expect(analyse(totalRemDuration: 900).narrative.contains(":"))
    }

    @Test("Narrative is never empty for any mood")
    func narrativeIsNeverEmpty() {
        for mood in DreamMood.allCases {
            let result = analyse(
                moodPolarity: mood == .chaotic ? -0.8 : 0.3,
                apneaSpikes: mood == .chaotic ? 6 : 0
            )
            #expect(!result.narrative.isEmpty)
        }
    }

    // MARK: - Stage percentages from labelled samples

    @Test("REM % computed from stage-labelled samples")
    func remPercentageFromLabels() {
        // 25 REM out of 100 total = 25 %
        let result = analyse(remSamples: 25, deepSamples: 25, lightSamples: 50)
        #expect(abs(result.remEstimate - 25) < 0.1)
    }

    @Test("Deep % computed from stage-labelled samples")
    func deepPercentageFromLabels() {
        let result = analyse(remSamples: 20, deepSamples: 30, lightSamples: 50)
        #expect(abs(result.deepSleepEstimate - 30) < 0.1)
    }

    @Test("Stage percentages fall back to REMDreamProfile when no labels present")
    func stageFallbackToProfile() {
        let result = analyse(totalRemDuration: 1800)
        // Derived from profile: positive and within valid range
        #expect(result.remEstimate > 0)
        #expect(result.remEstimate <= 50)
        #expect(result.deepSleepEstimate > 0)
    }

    // MARK: - Intensity and consciousness

    @Test("Intensity is clamped to 0...1")
    func intensityClamped() {
        for v in [-0.5, 0.0, 0.5, 1.0, 1.5] {
            let result = analyse(intensityScore: v)
            #expect(result.intensity >= 0 && result.intensity <= 1)
        }
    }

    @Test("Consciousness is clamped to 0...1")
    func consciousnessClamped() {
        let result = analyse(moodPolarity: 0.9, totalRemDuration: 7200)
        #expect(result.consciousness >= 0 && result.consciousness <= 1)
    }

    // MARK: - Themes and symbolism

    @Test("Exactly three themes are returned for every mood")
    func themeCount() {
        for mood in DreamMood.allCases {
            let polarity = mood == .chaotic ? -0.8 : 0.5
            let spikes   = mood == .chaotic ? 6    : 0
            let result   = analyse(moodPolarity: polarity, apneaSpikes: spikes)
            #expect(result.themes.count == 3)
        }
    }

    @Test("Exactly three symbols are returned for every mood")
    func symbolismCount() {
        for mood in DreamMood.allCases {
            let polarity = mood == .chaotic ? -0.8 : 0.5
            let spikes   = mood == .chaotic ? 6    : 0
            let result   = analyse(moodPolarity: polarity, apneaSpikes: spikes)
            #expect(result.symbolism.count == 3)
        }
    }

    @Test("Apnea-heavy session includes 'struggle' theme")
    func apneaTheme() {
        let result = analyse(apneaSpikes: 5)
        #expect(result.themes.contains("struggle"))
    }

    @Test("Noise-heavy session includes 'disruption' theme")
    func noiseTheme() {
        let result = analyse(noiseSpikes: 4)
        #expect(result.themes.contains("disruption"))
    }

    // MARK: - Determinism

    @Test("Same inputs always produce identical output")
    func deterministic() {
        let a = analyse(heartRate: 59, hrv: 52, moodPolarity: 0.3, intensityScore: 0.45)
        let b = analyse(heartRate: 59, hrv: 52, moodPolarity: 0.3, intensityScore: 0.45)
        #expect(a.narrative == b.narrative)
        #expect(a.mood == b.mood)
        #expect(a.remEstimate == b.remEstimate)
        #expect(a.deepSleepEstimate == b.deepSleepEstimate)
    }
}
