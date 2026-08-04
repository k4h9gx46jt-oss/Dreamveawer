import Foundation
import Testing
@testable import DreamWeaver

@MainActor
@Suite("Phone-watch connectivity logic", .serialized)
struct PhoneWatchConnectivityTests {

    private func makePayload(timestamp: TimeInterval = 1_700_000_000) -> [String: Any] {
        [
            "timestamp": timestamp,
            "heartRate": 61.0,
            "hrv": 48.0,
            "movement": 0.12,
            "spo2": 97.0,
            "respiratoryRate": 14.0,
            "ecgConfidence": 0.9,
            "hypertensionRisk": 0.2,
            "temperatureDelta": 0.4,
            "sleepScore": 86.0,
            "noiseExposure": 33.0,
            "apneaRisk": 0.08,
            "remState": REMState.rem.rawValue
        ]
    }

    @Test("decodeSample maps required and optional fields")
    func decodeSampleMapsAllFields() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let sample = sut._test_decodeSample(from: makePayload())
        #expect(sample != nil)
        #expect(sample?.heartRate == 61.0)
        #expect(sample?.hrv == 48.0)
        #expect(sample?.sleepStage == .rem)
        #expect(sample?.noiseExposure == 33.0)
    }

    @Test("decodeSample returns nil without required fields")
    func decodeSampleRequiresTimestampHeartRateAndHRV() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        #expect(sut._test_decodeSample(from: ["heartRate": 60.0, "hrv": 50.0]) == nil)
        #expect(sut._test_decodeSample(from: ["timestamp": 1_700_000_000, "hrv": 50.0]) == nil)
        #expect(sut._test_decodeSample(from: ["timestamp": 1_700_000_000, "heartRate": 60.0]) == nil)
    }

    @Test("decodeSample falls back to current live metrics when optional fields are missing")
    func decodeSampleUsesLiveFallbacks() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        sut.liveSpO2 = 95
        sut.liveRespiratoryRate = 13
        sut.liveECGConfidence = 0.77
        sut.liveHypertensionRisk = 0.44
        sut.liveTemperatureDelta = -0.2
        sut.liveSleepScore = 71
        sut.liveNoiseExposure = 41
        sut.liveApneaRisk = 0.19

        let sample = sut._test_decodeSample(from: [
            "timestamp": 1_700_000_000.0,
            "heartRate": 59.0,
            "hrv": 52.0
        ])

        #expect(sample != nil)
        #expect(sample?.spo2 == 95)
        #expect(sample?.respiratoryRate == 13)
        #expect(sample?.ecgConfidence == 0.77)
        #expect(sample?.hypertensionRisk == 0.44)
        #expect(sample?.wristTemperatureDelta == -0.2)
        #expect(sample?.sleepScore == 71)
        #expect(sample?.noiseExposure == 41)
        #expect(sample?.apneaRisk == 0.19)
    }

    @Test("normalizedLiveSamples sorts ascending and de-duplicates near-identical timestamps")
    func normalizedSamplesSortAndDeduplicate() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let older = BiosignalDataPoint(timestamp: t0, heartRate: 60, hrv: 50)
        let newerDuplicate = BiosignalDataPoint(timestamp: t0.addingTimeInterval(0.1), heartRate: 62, hrv: 51)
        let late = BiosignalDataPoint(timestamp: t0.addingTimeInterval(1), heartRate: 64, hrv: 52)

        let normalized = sut._test_normalizedLiveSamples([late, older, newerDuplicate])

        #expect(normalized.count == 2)
        #expect(normalized[0].timestamp == newerDuplicate.timestamp)
        #expect(normalized[0].heartRate == 62)
        #expect(normalized[1].timestamp == late.timestamp)
    }

    @Test("normalizedLiveSamples keeps samples that are outside de-dup threshold")
    func normalizedSamplesKeepSeparatedTimestamps() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let a = BiosignalDataPoint(timestamp: t0, heartRate: 60, hrv: 50)
        let b = BiosignalDataPoint(timestamp: t0.addingTimeInterval(0.3), heartRate: 61, hrv: 50)

        let normalized = sut._test_normalizedLiveSamples([a, b])
        #expect(normalized.count == 2)
    }

    @Test("normalizedLiveSamples enforces retention limit")
    func normalizedSamplesRetentionCap() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = (0..<900).map { idx in
            BiosignalDataPoint(timestamp: t0.addingTimeInterval(Double(idx)), heartRate: 60, hrv: 50)
        }
        let normalized = sut._test_normalizedLiveSamples(samples)
        #expect(normalized.count == 720)
    }

    @Test("updateREM opens and closes windows on state transitions")
    func remWindowStateTransitions() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        sut._test_updateREM(with: Date(timeIntervalSince1970: 1_700_000_000), state: REMState.rem.rawValue)
        sut._test_updateREM(with: Date(timeIntervalSince1970: 1_700_000_120), state: REMState.deep.rawValue)

        #expect(sut.remWindows.count == 1)
        #expect(sut.liveSleepStage == "Deep")
    }

    @Test("finalizeREMWindow closes active REM and marks stage idle")
    func finalizeRemWindow() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        sut._test_updateREM(with: Date(timeIntervalSince1970: 1_700_000_000), state: REMState.rem.rawValue)
        sut._test_finalizeREMWindow(until: Date(timeIntervalSince1970: 1_700_000_180))

        #expect(sut.remWindows.count == 1)
        #expect(sut.liveSleepStage == "Idle")
    }

    @Test("status snapshot reports tracking false when no session is active")
    func statusSnapshotIdle() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let payload = sut._test_statusSnapshotPayload()
        #expect((payload["tracking"] as? Bool) == false)
    }

    @Test("applyLiveSample updates live metrics and stage")
    func applyLiveSampleUpdatesMetrics() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let sample = BiosignalDataPoint(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            heartRate: 67,
            hrv: 43,
            movement: 0.11,
            spo2: 96,
            respiratoryRate: 15,
            ecgConfidence: 0.88,
            hypertensionRisk: 0.31,
            wristTemperatureDelta: 0.5,
            sleepScore: 82,
            noiseExposure: 38,
            apneaRisk: 0.14,
            sleepStage: .rem
        )

        sut._test_applyLiveSample(sample, remState: REMState.rem.rawValue)
        #expect(sut.liveHeartRate == 67)
        #expect(sut.liveHRV == 43)
        #expect(sut.liveSpO2 == 96)
        #expect(sut.liveSleepStage == "REM")
        #expect(sut.sleepSamples.count == 1)
    }

    @Test("handleEvent sleepStart updates remote tracking state")
    func handleEventSleepStart() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let id = UUID()
        sut._test_handleEvent("sleepStart", payload: [
            "event": "sleepStart",
            "sessionId": id.uuidString,
            "start": 1_700_000_000.0
        ])

        #expect(sut.remoteSessionId == id)
        #expect(sut.remoteSessionStart == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(sut.remoteSessionEndedAt == nil)
    }

    @Test("handleEvent sampleBatch processes entries in timestamp order")
    func handleEventSampleBatchOrdering() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let t = 1_700_000_000.0

        sut._test_handleEvent("sampleBatch", payload: [
            "event": "sampleBatch",
            "samples": [
                makePayload(timestamp: t + 10),
                makePayload(timestamp: t + 1),
                makePayload(timestamp: t + 5)
            ]
        ])

        #expect(sut.sleepSamples.count == 3)
        #expect(sut.sleepSamples[0].timestamp == Date(timeIntervalSince1970: t + 1))
        #expect(sut.sleepSamples[2].timestamp == Date(timeIntervalSince1970: t + 10))
    }

    @Test("handleEvent sleepEnd finalizes REM and clears active remote session")
    func handleEventSleepEndFinalizes() {
        let sut = PhoneWatchConnectivityManager.shared
        sut._test_resetLiveState()
        let id = UUID()
        sut._test_updateREM(with: Date(timeIntervalSince1970: 1_700_000_100), state: REMState.rem.rawValue)

        sut._test_handleEvent("sleepEnd", payload: [
            "event": "sleepEnd",
            "sessionId": id.uuidString,
            "start": 1_700_000_000.0,
            "end": 1_700_000_300.0,
            "samples": [makePayload(timestamp: 1_700_000_250.0)]
        ])

        #expect(sut.remoteSessionStart == nil)
        #expect(sut.remoteSessionEndedAt == Date(timeIntervalSince1970: 1_700_000_300))
        #expect(sut.liveSleepStage == "Idle")
    }
}
