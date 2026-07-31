import Foundation
import Testing
@testable import DreamWeaver

/// Guards the path from raw samples to a `REMDreamProfile`.
///
/// This is the pipeline's narrowest point: `DreamMediaComposer` throws
/// `missingREMProfile` when the profile is nil, so a night that produces no
/// profile produces no dream film at all — the product's entire output.
@Suite("REM profiling")
struct REMProfileTests {

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func sample(offset: TimeInterval,
                        heartRate: Double = 58,
                        hrv: Double = 55,
                        movement: Double = 0.05,
                        stage: REMState? = nil) -> BiosignalDataPoint {
        BiosignalDataPoint(
            timestamp: start.addingTimeInterval(offset),
            heartRate: heartRate,
            hrv: hrv,
            movement: movement,
            spo2: 97,
            respiratoryRate: 14,
            ecgConfidence: 0.9,
            hypertensionRisk: 0.1,
            wristTemperatureDelta: 0.1,
            sleepScore: 85,
            noiseExposure: 32,
            apneaRisk: 0.05,
            sleepStage: stage
        )
    }

    private func session(_ samples: [BiosignalDataPoint]) -> SleepSession {
        var session = SleepSession(startedAt: start, biosignals: samples)
        session.finish(on: start.addingTimeInterval(3600))
        session.analyzeREMProfile()
        return session
    }

    // MARK: - The regression this suite exists for

    @Test("A restless night still produces a profile")
    func restlessNightStillProfiles() {
        // Every sample is above the old movement ceiling. Before staging was
        // transported this produced zero segments, a nil profile, and no film.
        let samples = stride(from: 0.0, through: 1800, by: 30).map {
            sample(offset: $0, movement: 0.9, stage: .awake)
        }
        let profile = session(samples).remProfile

        #expect(profile != nil)
        #expect(profile?.segments.isEmpty == false)
        #expect((profile?.totalDuration ?? 0) > 0)
    }

    @Test("A night with no REM at all still produces a profile")
    func noREMStillProfiles() {
        let samples = stride(from: 0.0, through: 1800, by: 30).map {
            sample(offset: $0, heartRate: 44, stage: .deep)
        }
        #expect(session(samples).remProfile != nil)
    }

    @Test("An empty session has no profile")
    func emptySessionHasNoProfile() {
        var empty = SleepSession(startedAt: start, biosignals: [])
        empty.finish(on: start.addingTimeInterval(3600))
        empty.analyzeREMProfile()

        #expect(empty.remProfile == nil)
    }

    // MARK: - Staging drives segmentation

    @Test("Recorded stages decide segments, not the movement heuristic")
    func recordedStagesWin() throws {
        // Movement says "still" everywhere, so the old heuristic would call the
        // whole night REM. The recorded stages say only the middle third is.
        let samples = stride(from: 0.0, through: 1800, by: 10).map { offset -> BiosignalDataPoint in
            let stage: REMState = (600...1200).contains(offset) ? .rem : .deep
            return sample(offset: offset, movement: 0.02, stage: stage)
        }
        let profile = try #require(session(samples).remProfile)

        #expect(profile.segments.count >= 1)
        for segment in profile.segments {
            #expect(segment.end >= segment.start)
        }
        // Well short of the full 30 minutes, which is what the old rule produced.
        #expect(profile.totalDuration < 1500)
    }

    @Test("Samples without a stage fall back to the movement heuristic")
    func fallsBackToMovementWhenUnstaged() {
        let still = stride(from: 0.0, through: 600, by: 10).map {
            sample(offset: $0, movement: 0.05, stage: nil)
        }
        let restless = stride(from: 0.0, through: 600, by: 10).map {
            sample(offset: $0, movement: 0.95, stage: nil)
        }

        let stillProfile = session(still).remProfile
        let restlessProfile = session(restless).remProfile

        #expect((stillProfile?.segments.count ?? 0) > (restlessProfile?.segments.count ?? 0))
    }

    @Test("A bucket is REM only when most of its samples are")
    func majorityDecidesBucket() {
        let mostlyREM = (0..<10).map { index in
            sample(offset: Double(index), stage: index < 7 ? .rem : .light)
        }
        let mostlyLight = (0..<10).map { index in
            sample(offset: Double(index), stage: index < 3 ? .rem : .light)
        }

        #expect(REMDreamProfile.isREM(mostlyREM))
        #expect(!REMDreamProfile.isREM(mostlyLight))
    }

    // MARK: - Transport

    @Test("Sleep stage survives a coding round trip")
    func stageSurvivesCoding() throws {
        let point = sample(offset: 0, stage: .rem)
        let decoded = try JSONDecoder().decode(BiosignalDataPoint.self,
                                               from: JSONEncoder().encode(point))
        #expect(decoded.sleepStage == .rem)
        #expect(decoded.movement == point.movement)
    }

    @Test("A sample recorded before staging existed still decodes")
    func legacySampleDecodes() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "timestamp": 0,
          "heartRate": 60,
          "hrv": 50,
          "movement": 0.1,
          "spo2": 97,
          "respiratoryRate": 14,
          "ecgConfidence": 0.9,
          "hypertensionRisk": 0.1,
          "wristTemperatureDelta": 0,
          "sleepScore": 85,
          "noiseExposure": 30,
          "apneaRisk": 0.05
        }
        """
        let decoded = try JSONDecoder().decode(BiosignalDataPoint.self,
                                               from: Data(json.utf8))
        #expect(decoded.sleepStage == nil)
    }

    @Test("Every REMState round trips through its transported raw value")
    func stageRawValuesRoundTrip() {
        for state in [REMState.awake, .light, .deep, .rem] {
            #expect(REMState(rawValue: state.rawValue) == state)
        }
    }
}
