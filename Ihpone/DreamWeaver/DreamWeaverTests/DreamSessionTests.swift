import Foundation
import Testing
@testable import DreamWeaver

@Suite("Dream session lifecycle")
struct DreamSessionTests {

    @Test("A new session starts with an open end date")
    func sessionStarts() {
        let session = SleepSession(startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(session.endedAt == nil)
        #expect(session.biosignals.isEmpty)
    }

    @Test("Finishing a session stamps the end date")
    func sessionStops() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SleepSession(startedAt: start)
        session.finish(on: start.addingTimeInterval(3600))

        let end = try? #require(session.endedAt)
        #expect(end == start.addingTimeInterval(3600))
        #expect(end?.timeIntervalSince(start) == 3600)
    }

    @Test("Stopping recomputes the averages from the captured samples")
    func stopRecalculatesAverages() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SleepSession(startedAt: start,
                                   biosignals: DreamFixture.biosignals(from: start, count: 30))
        session.finish(on: start.addingTimeInterval(1800))
        session.recalculateAverages()

        #expect(session.averageHeartRate > 50 && session.averageHeartRate < 75)
        #expect(session.hrvAverage > 40 && session.hrvAverage < 70)
        #expect(session.ambientNoiseAvg > 0)
    }

    @Test("Averages stay untouched when no samples arrived")
    func emptySessionKeepsDefaults() {
        var session = SleepSession(startedAt: Date(), averageHeartRate: 60, hrvAverage: 52)
        session.recalculateAverages()

        #expect(session.averageHeartRate == 60)
        #expect(session.hrvAverage == 52)
    }

    @Test("Stopping builds a REM profile from calm samples")
    func stopBuildsREMProfile() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SleepSession(startedAt: start,
                                   biosignals: DreamFixture.biosignals(from: start, count: 60))
        session.finish(on: start.addingTimeInterval(3600))
        session.analyzeREMProfile()

        let profile = try #require(session.remProfile)
        #expect(!profile.segments.isEmpty)
        #expect(profile.totalDuration > 0)
        #expect(profile.intensityScore >= 0 && profile.intensityScore <= 1)
        #expect(profile.moodPolarity >= -1 && profile.moodPolarity <= 1)
    }

    @Test("Restless sleep still yields a profile so a film can be rendered")
    func restlessSleepStillProfiles() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var restless = SleepSession(startedAt: start,
                                    biosignals: DreamFixture.biosignals(from: start, count: 40, movement: 0.9))
        restless.finish()
        restless.analyzeREMProfile()

        var settled = SleepSession(startedAt: start,
                                   biosignals: DreamFixture.biosignals(from: start, count: 40, movement: 0.05))
        settled.finish()
        settled.analyzeREMProfile()

        // A missing profile makes DreamMediaComposer throw, which would leave a
        // recorded night with no dream film at all.
        let profile = try #require(restless.remProfile)
        #expect(!profile.segments.isEmpty)

        // Restlessness still has to register as less REM than a settled night.
        let settledProfile = try #require(settled.remProfile)
        #expect(profile.segments.count < settledProfile.segments.count)
    }

    @Test("A session without samples has no REM profile")
    func emptySessionHasNoREM() {
        var session = SleepSession(startedAt: Date())
        session.analyzeREMProfile()

        #expect(session.remProfile == nil)
    }

    @Test("Apnea spikes are surfaced as the dominant driver")
    func apneaDominatesProfile() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SleepSession(startedAt: start,
                                   biosignals: DreamFixture.biosignals(from: start,
                                                                       count: 40,
                                                                       apneaRisk: 0.9))
        session.finish()
        session.analyzeREMProfile()

        let profile = try #require(session.remProfile)
        #expect(profile.apneaSpikeCount > 0)
        #expect(profile.segments.allSatisfy { $0.dominantDriver == .apnea })
    }

    @Test("Loud rooms are surfaced as the noise driver")
    func noiseDominatesProfile() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SleepSession(startedAt: start,
                                   biosignals: DreamFixture.biosignals(from: start,
                                                                       count: 40,
                                                                       noiseExposure: 70))
        session.finish()
        session.analyzeREMProfile()

        let profile = try #require(session.remProfile)
        #expect(profile.noiseSpikeCount > 0)
    }

    @Test("Segments are ordered and never overlap")
    func segmentsAreOrdered() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SleepSession(startedAt: start,
                                   biosignals: DreamFixture.biosignals(from: start, count: 90))
        session.finish()
        session.analyzeREMProfile()

        let segments = try #require(session.remProfile?.segments)
        for segment in segments {
            #expect(segment.end >= segment.start)
        }
        for pair in zip(segments, segments.dropFirst()) {
            #expect(pair.1.start >= pair.0.start)
        }
    }

    @Test("Trend detection reacts to the direction of change")
    func trendDetection() {
        #expect(REMTrend.from(first: 50, last: 60) == .rising)
        #expect(REMTrend.from(first: 60, last: 50) == .falling)
        #expect(REMTrend.from(first: 60, last: 60.5) == .stable)
    }
}

@Suite("Dream store", .serialized)
@MainActor
struct DreamStoreTests {

    @Test("Starting a session marks it active")
    func startSession() {
        let store = SleepDataStore()
        #expect(store.activeSession == nil)

        store.startNewSession()
        #expect(store.activeSession != nil)
    }

    @Test("Starting twice keeps the first session")
    func startIsIdempotent() throws {
        let store = SleepDataStore()
        store.startNewSession()
        let first = try #require(store.activeSession?.id)

        store.startNewSession()
        #expect(store.activeSession?.id == first)
    }

    @Test("Stopping a session files the dream and clears the active one")
    func stopSessionStoresDream() throws {
        let store = SleepDataStore()
        let initialCount = store.dreams.count
        store.startNewSession()
        var session = try #require(store.activeSession)
        session.finish()

        let aiResult = SleepAIResult(narrative: "n",
                                     themes: ["a"],
                                     symbolism: ["⭐"],
                                     intensity: 0.5,
                                     consciousness: 0.3,
                                     visualPrompt: "p",
                                     mood: .ethereal,
                                     remEstimate: 25,
                                     deepSleepEstimate: 30)
        let dream = store.addDream(from: session, aiResult: aiResult)

        #expect(store.activeSession == nil)
        #expect(store.dreams.count == initialCount + 1)
        #expect(store.dreams.first?.id == dream.id)
        #expect(dream.mood == .ethereal)
    }

    @Test("A remote watch session is ingested end to end")
    func ingestRemoteSession() async {
        let store = SleepDataStore()
        let initialCount = store.dreams.count
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        await store.ingestRemoteSession(
            RemoteSleepSessionResult(sessionId: UUID(),
                                     startedAt: start,
                                     endedAt: start.addingTimeInterval(3600),
                                     samples: DreamFixture.biosignals(from: start, count: 60))
        )

        #expect(store.dreams.count == initialCount + 1)
        #expect(store.dreams.first?.remProfile != nil)
    }

    @Test("Persisting a session derives a REM profile when one is missing")
    func persistDerivesREMProfile() async throws {
        let store = SleepDataStore()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SleepSession(startedAt: start,
                                   biosignals: DreamFixture.biosignals(from: start, count: 60))
        session.finish(on: start.addingTimeInterval(3600))

        let dream = try #require(await store.persistSession(session))
        #expect(dream.remProfile != nil)
        #expect(dream.duration == 3600)
    }
}
