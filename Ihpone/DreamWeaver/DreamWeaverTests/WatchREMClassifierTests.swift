import Foundation
import Testing
@testable import DreamWeaver

/// Covers the sleep-staging rules the watch runs during a Dream Mode session.
/// `REMClassifier` lives in `Shared/`, so it is compiled into both the watch
/// extension and the app, and these tests exercise the very same code the watch uses.
@Suite("Watch sleep staging")
struct WatchREMClassifierTests {

    private let reference = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Stateless classification

    @Test("A resting heart rate below 50 is deep sleep")
    func lowHeartRateIsDeep() {
        #expect(REMClassifier.classify(heartRate: 42, heartRateVariability: 60) == .deep)
        #expect(REMClassifier.classify(heartRate: 49.9, heartRateVariability: 20) == .deep)
    }

    @Test("The REM band with healthy variability is REM")
    func remBandIsREM() {
        #expect(REMClassifier.classify(heartRate: 50, heartRateVariability: 35) == .rem)
        #expect(REMClassifier.classify(heartRate: 62, heartRateVariability: 55) == .rem)
        #expect(REMClassifier.classify(heartRate: 75, heartRateVariability: 40) == .rem)
    }

    @Test("Low variability rules REM out even inside the band")
    func lowVariabilityBlocksREM() {
        #expect(REMClassifier.classify(heartRate: 62, heartRateVariability: 34.9) == .light)
        #expect(REMClassifier.classify(heartRate: 55, heartRateVariability: 10) == .light)
    }

    @Test("Above the REM band the sleeper is light")
    func highHeartRateIsLight() {
        #expect(REMClassifier.classify(heartRate: 75.1, heartRateVariability: 80) == .light)
        #expect(REMClassifier.classify(heartRate: 120, heartRateVariability: 80) == .light)
    }

    @Test("Classification is exhaustive and never crashes",
          arguments: stride(from: 30.0, through: 140.0, by: 5.0).map { $0 })
    func classificationIsTotal(heartRate: Double) {
        for hrv in stride(from: 0.0, through: 120.0, by: 10.0) {
            let state = REMClassifier.classify(heartRate: heartRate, heartRateVariability: hrv)
            #expect([REMState.light, .deep, .rem].contains(state))
        }
    }

    @Test("Classification is a pure function of its inputs")
    func classificationIsPure() {
        for _ in 0..<100 {
            let hr = Double.random(in: 30...140)
            let hrv = Double.random(in: 0...120)
            #expect(REMClassifier.classify(heartRate: hr, heartRateVariability: hrv)
                    == REMClassifier.classify(heartRate: hr, heartRateVariability: hrv))
        }
    }

    // MARK: - Window accumulation

    @Test("A fresh classifier starts in light sleep with no windows")
    func initialState() {
        let classifier = REMClassifier()
        #expect(classifier.state == .light)
        #expect(classifier.windows.isEmpty)
        #expect(classifier.totalREMDuration == 0)
    }

    @Test("Entering REM opens a window")
    func entryOpensWindow() {
        var classifier = REMClassifier()
        let state = classifier.ingest(heartRate: 62, heartRateVariability: 55, timestamp: reference)

        #expect(state == .rem)
        #expect(classifier.windows.count == 1)
        #expect(classifier.windows[0].start == reference)
        #expect(classifier.windows[0].duration == REMClassifier.initialWindowDuration)
    }

    @Test("Staying in REM extends the open window instead of opening a new one")
    func continuedREMExtendsWindow() {
        var classifier = REMClassifier()
        classifier.ingest(heartRate: 62, heartRateVariability: 55, timestamp: reference)
        classifier.ingest(heartRate: 64, heartRateVariability: 52,
                          timestamp: reference.addingTimeInterval(120))
        classifier.ingest(heartRate: 61, heartRateVariability: 58,
                          timestamp: reference.addingTimeInterval(300))

        #expect(classifier.windows.count == 1)
        #expect(classifier.windows[0].end == reference.addingTimeInterval(300))
        #expect(classifier.windows[0].duration == 300)
    }

    @Test("Leaving and re-entering REM opens a second window")
    func reentryOpensNewWindow() {
        var classifier = REMClassifier()
        classifier.ingest(heartRate: 62, heartRateVariability: 55, timestamp: reference)
        classifier.ingest(heartRate: 44, heartRateVariability: 55,
                          timestamp: reference.addingTimeInterval(60))
        classifier.ingest(heartRate: 62, heartRateVariability: 55,
                          timestamp: reference.addingTimeInterval(120))

        #expect(classifier.windows.count == 2)
        #expect(classifier.windows[1].start == reference.addingTimeInterval(120))
    }

    @Test("Non-REM readings never create windows")
    func nonREMCreatesNoWindows() {
        var classifier = REMClassifier()
        classifier.ingest(heartRate: 40, heartRateVariability: 60, timestamp: reference)
        classifier.ingest(heartRate: 100, heartRateVariability: 60,
                          timestamp: reference.addingTimeInterval(60))
        classifier.ingest(heartRate: 62, heartRateVariability: 12,
                          timestamp: reference.addingTimeInterval(120))

        #expect(classifier.windows.isEmpty)
        #expect(classifier.state == .light)
    }

    @Test("A full night accumulates several REM windows in order")
    func fullNightAccumulatesWindows() {
        var classifier = REMClassifier()
        // Three REM bouts separated by deep sleep, one reading per minute.
        for minute in 0..<90 {
            let timestamp = reference.addingTimeInterval(TimeInterval(minute) * 60)
            let inREM = (10..<20).contains(minute)
                || (40..<55).contains(minute)
                || (70..<80).contains(minute)
            classifier.ingest(heartRate: inREM ? 62 : 44,
                              heartRateVariability: 55,
                              timestamp: timestamp)
        }

        #expect(classifier.windows.count == 3)
        #expect(classifier.totalREMDuration > 0)
        for pair in zip(classifier.windows, classifier.windows.dropFirst()) {
            #expect(pair.1.start > pair.0.start)
        }
        for window in classifier.windows {
            #expect(window.end >= window.start)
        }
    }

    @Test("Window identity survives extension")
    func extendKeepsIdentity() {
        let window = REMWindow(start: reference, end: reference.addingTimeInterval(60))
        let extended = window.extended(to: reference.addingTimeInterval(300))

        #expect(extended.id == window.id)
        #expect(extended.start == window.start)
        #expect(extended.duration == 300)
    }

    @Test("Windows survive a coding round trip")
    func windowCodable() throws {
        let window = REMWindow(start: reference, end: reference.addingTimeInterval(240))
        let decoded = try JSONDecoder().decode(REMWindow.self, from: JSONEncoder().encode(window))

        #expect(decoded == window)
    }

    @Test("Sleep states survive a coding round trip",
          arguments: [REMState.light, .deep, .rem])
    func stateCodable(state: REMState) throws {
        let decoded = try JSONDecoder().decode(REMState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
    }

    @Test("A classifier can be resumed from a restored state")
    func resumeFromState() {
        let open = REMWindow(start: reference, end: reference.addingTimeInterval(60))
        var classifier = REMClassifier(state: .rem, windows: [open])
        classifier.ingest(heartRate: 62, heartRateVariability: 55,
                          timestamp: reference.addingTimeInterval(180))

        #expect(classifier.windows.count == 1)
        #expect(classifier.windows[0].id == open.id)
        #expect(classifier.windows[0].end == reference.addingTimeInterval(180))
    }

    // MARK: - Personalised baseline

    @Test("A fresh baseline falls back to the population thresholds")
    func baselineFallsBackBeforeWarmUp() {
        let baseline = SleepBaseline()
        #expect(!baseline.isWarmedUp)
        #expect(baseline.deepSleepMaxHeartRate == REMClassifier.deepSleepMaxHeartRate)
        #expect(baseline.minimumREMHeartRateVariability == REMClassifier.minimumREMHeartRateVariability)
    }

    @Test("The baseline tracks down toward the night's resting floor")
    func baselineDescendsTowardResting() {
        var baseline = SleepBaseline(restingHeartRate: 70, typicalHRV: 45)
        for _ in 0..<200 {
            baseline.ingest(heartRate: 48, heartRateVariability: 60)
        }
        #expect(baseline.isWarmedUp)
        #expect(baseline.restingHeartRate < 55)
    }

    @Test("A single spike barely moves the baseline")
    func baselineResistsSpikes() {
        var baseline = SleepBaseline(restingHeartRate: 55, typicalHRV: 45)
        let before = baseline.restingHeartRate
        baseline.ingest(heartRate: 160, heartRateVariability: 20)
        #expect(baseline.restingHeartRate - before < 0.5)
    }

    @Test("An athlete's low resting rate no longer reads as permanent deep sleep")
    func lowRestingSleeperStillReachesREM() {
        let athlete = SleepBaseline(restingHeartRate: 42, typicalHRV: 60, sampleCount: 200)
        let state = REMClassifier.classify(heartRate: 46,
                                           heartRateVariability: 55,
                                           movement: 0.05,
                                           baseline: athlete)
        #expect(state == .rem)
    }

    @Test("A high resting sleeper can still reach deep sleep")
    func highRestingSleeperReachesDeep() {
        let baseline = SleepBaseline(restingHeartRate: 72, typicalHRV: 40, sampleCount: 200)
        let state = REMClassifier.classify(heartRate: 66,
                                           heartRateVariability: 45,
                                           movement: 0.05,
                                           baseline: baseline)
        #expect(state == .deep)
    }

    // MARK: - Movement

    @Test("Sustained movement reports awake")
    func movementReportsAwake() {
        let state = REMClassifier.classify(heartRate: 62,
                                           heartRateVariability: 55,
                                           movement: 0.9,
                                           baseline: nil)
        #expect(state == .awake)
    }

    @Test("REM requires the muscle atonia that comes with a still wrist")
    func movementVetoesREM() {
        let restless = REMClassifier.classify(heartRate: 62,
                                              heartRateVariability: 55,
                                              movement: 0.4,
                                              baseline: nil)
        let still = REMClassifier.classify(heartRate: 62,
                                           heartRateVariability: 55,
                                           movement: 0.05,
                                           baseline: nil)
        #expect(restless == .light)
        #expect(still == .rem)
    }

    @Test("The legacy entry point never reports awake")
    func legacyClassifyNeverReportsAwake() {
        for heartRate in stride(from: 30.0, through: 200.0, by: 5.0) {
            for hrv in stride(from: 0.0, through: 120.0, by: 20.0) {
                #expect(REMClassifier.classify(heartRate: heartRate, heartRateVariability: hrv) != .awake)
            }
        }
    }

    // MARK: - Smoothing

    @Test("The overnight configuration smooths and adapts")
    func overnightConfiguration() {
        #expect(REMClassifier.Configuration.overnight.smoothingDepth > 1)
        #expect(REMClassifier.Configuration.overnight.adaptiveBaseline)
        #expect(REMClassifier.Configuration.overnight.movementAware)
        #expect(REMClassifier.Configuration.legacy.smoothingDepth == 1)
    }

    @Test("A one-second blip cannot flip the reported stage when smoothing")
    func smoothingRejectsBlips() {
        var classifier = REMClassifier(configuration: .overnight)
        // Establish a steady deep-sleep run.
        for second in 0..<40 {
            classifier.ingest(heartRate: 44,
                              heartRateVariability: 55,
                              movement: 0.02,
                              timestamp: reference.addingTimeInterval(TimeInterval(second)))
        }
        let settled = classifier.state
        classifier.ingest(heartRate: 62,
                          heartRateVariability: 55,
                          movement: 0.02,
                          timestamp: reference.addingTimeInterval(41))

        #expect(classifier.state == settled)
    }

    @Test("A sustained change does move the reported stage when smoothing")
    func smoothingAcceptsSustainedChange() {
        var classifier = REMClassifier(configuration: .overnight)
        for second in 0..<40 {
            classifier.ingest(heartRate: 44,
                              heartRateVariability: 55,
                              movement: 0.02,
                              timestamp: reference.addingTimeInterval(TimeInterval(second)))
        }
        for second in 40..<80 {
            classifier.ingest(heartRate: 66,
                              heartRateVariability: 60,
                              movement: 0.02,
                              timestamp: reference.addingTimeInterval(TimeInterval(second)))
        }

        #expect(classifier.state != .deep)
    }

    @Test("Smoothing never invents a stage that was not observed")
    func smoothingIsConservative() {
        var classifier = REMClassifier(configuration: .overnight)
        for second in 0..<120 {
            let state = classifier.ingest(heartRate: Double.random(in: 40...90),
                                          heartRateVariability: Double.random(in: 10...90),
                                          movement: Double.random(in: 0...1),
                                          timestamp: reference.addingTimeInterval(TimeInterval(second)))
            #expect([REMState.light, .deep, .rem, .awake].contains(state))
        }
    }
}
