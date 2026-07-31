import Foundation
import Testing
@testable import DreamWeaver

/// Covers the automatic Dream Mode triggers: the recurring nightly window taken
/// from the user's sleep schedule, and the onset detector that confirms it with
/// heart rate and wrist motion.
@Suite("Automatic sleep detection")
struct SleepAutoStartTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int, day: Int = 15) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    // MARK: - Sleep window

    @Test("A 22:00 to 06:00 window crosses midnight")
    func windowCrossesMidnight() {
        let window = SleepWindow(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)
        #expect(window.crossesMidnight)
        #expect(window.duration == 8 * 3600)
    }

    @Test("A daytime window does not cross midnight")
    func daytimeWindow() {
        let window = SleepWindow(startHour: 13, startMinute: 0, endHour: 15, endMinute: 30)
        #expect(!window.crossesMidnight)
        #expect(window.duration == 2.5 * 3600)
    }

    @Test("Times inside a midnight-crossing window are recognised")
    func containsAcrossMidnight() {
        let window = SleepWindow(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

        #expect(window.contains(date(22, 0), calendar: calendar))
        #expect(window.contains(date(23, 30), calendar: calendar))
        #expect(window.contains(date(0, 1), calendar: calendar))
        #expect(window.contains(date(5, 59), calendar: calendar))
    }

    @Test("Times outside a midnight-crossing window are rejected")
    func excludesOutsideMidnightWindow() {
        let window = SleepWindow(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

        #expect(!window.contains(date(6, 0), calendar: calendar))
        #expect(!window.contains(date(12, 0), calendar: calendar))
        #expect(!window.contains(date(21, 59), calendar: calendar))
    }

    @Test("A same-day window only matches its own hours")
    func containsWithinDay() {
        let window = SleepWindow(startHour: 1, startMinute: 0, endHour: 7, endMinute: 0)

        #expect(window.contains(date(1, 0), calendar: calendar))
        #expect(window.contains(date(6, 59), calendar: calendar))
        #expect(!window.contains(date(7, 0), calendar: calendar))
        #expect(!window.contains(date(0, 59), calendar: calendar))
        #expect(!window.contains(date(23, 0), calendar: calendar))
    }

    @Test("Out-of-range components are normalised rather than trusted")
    func normalisesComponents() {
        let window = SleepWindow(startHour: 26, startMinute: 90, endHour: -2, endMinute: -5)

        #expect(window.startHour == 2)
        #expect(window.startMinute == 59)
        #expect(window.endHour == 22)
        #expect(window.endMinute == 0)
    }

    @Test("The next bedtime is in the future")
    func nextStartIsAhead() throws {
        let window = SleepWindow(startHour: 22, startMinute: 30, endHour: 6, endMinute: 0)
        let now = date(20, 0)
        let next = try #require(window.nextStart(after: now, calendar: calendar))

        #expect(next > now)
        let components = calendar.dateComponents([.hour, .minute], from: next)
        #expect(components.hour == 22)
        #expect(components.minute == 30)
    }

    // MARK: - Inferring the window from observed nights

    @Test("A consistent schedule is recovered from observed nights")
    func inferredFromIntervals() throws {
        let intervals = (0..<5).map { offset in
            DateInterval(start: date(23, 0, day: 10 + offset),
                         end: date(7, 0, day: 11 + offset))
        }
        let window = try #require(SleepWindow.inferred(from: intervals, calendar: calendar))

        #expect(window.startHour == 23)
        #expect(window.endHour == 7)
        #expect(window.crossesMidnight)
    }

    @Test("Bedtimes either side of midnight average to midnight, not to noon")
    func inferredHandlesMidnightWrap() throws {
        let intervals = [
            DateInterval(start: date(23, 50, day: 10), end: date(7, 0, day: 11)),
            DateInterval(start: date(0, 10, day: 12), end: date(7, 0, day: 12))
        ]
        let window = try #require(SleepWindow.inferred(from: intervals, calendar: calendar))

        #expect(window.startHour == 0)
        #expect(window.startMinute == 0)
    }

    @Test("An empty history infers nothing")
    func inferredRequiresData() {
        #expect(SleepWindow.inferred(from: [], calendar: calendar) == nil)
    }

    @Test("Windows survive a coding round trip")
    func windowCodable() throws {
        let window = SleepWindow(startHour: 22, startMinute: 45, endHour: 6, endMinute: 15)
        let decoded = try JSONDecoder().decode(SleepWindow.self, from: JSONEncoder().encode(window))
        #expect(decoded == window)
    }

    // MARK: - Onset detection

    @Test("A fresh detector reports awake")
    func detectorStartsAwake() {
        let detector = SleepOnsetDetector()
        #expect(detector.phase == .awake)
        #expect(detector.progress(at: date(23, 0)) == 0)
    }

    @Test("Movement keeps the detector awake no matter how low the heart rate")
    func movementBlocksOnset() {
        var detector = SleepOnsetDetector(baseline: SleepBaseline(restingHeartRate: 55,
                                                                 typicalHRV: 50,
                                                                 sampleCount: 200))
        for minute in 0..<30 {
            detector.ingest(heartRate: 50, movement: 0.8, timestamp: date(23, 0).addingTimeInterval(TimeInterval(minute) * 60))
        }
        #expect(detector.phase == .awake)
    }

    @Test("Lying still with an elevated heart rate is not sleep")
    func stillButAlertIsNotSleep() {
        var detector = SleepOnsetDetector(baseline: SleepBaseline(restingHeartRate: 55,
                                                                 typicalHRV: 50,
                                                                 sampleCount: 200))
        for minute in 0..<30 {
            detector.ingest(heartRate: 78, movement: 0.02, timestamp: date(23, 0).addingTimeInterval(TimeInterval(minute) * 60))
        }
        #expect(detector.phase == .awake)
    }

    @Test("Sustained quiet with a settled heart rate declares sleep")
    func sustainedQuietDeclaresSleep() {
        var detector = SleepOnsetDetector(baseline: SleepBaseline(restingHeartRate: 58,
                                                                 typicalHRV: 50,
                                                                 sampleCount: 200))
        let start = date(23, 0)
        var phase = SleepOnsetDetector.Phase.awake
        for minute in 0...10 {
            phase = detector.ingest(heartRate: 54,
                                    movement: 0.03,
                                    timestamp: start.addingTimeInterval(TimeInterval(minute) * 60))
        }
        #expect(phase == .asleep)
        #expect(detector.phase == .asleep)
    }

    @Test("Onset is reported as settling before the threshold is reached")
    func settlingBeforeThreshold() {
        var detector = SleepOnsetDetector(baseline: SleepBaseline(restingHeartRate: 58,
                                                                 typicalHRV: 50,
                                                                 sampleCount: 200))
        let start = date(23, 0)
        detector.ingest(heartRate: 54, movement: 0.03, timestamp: start)
        let phase = detector.ingest(heartRate: 54, movement: 0.03, timestamp: start.addingTimeInterval(60))

        #expect(phase == .settling)
        #expect(detector.progress(at: start.addingTimeInterval(60)) > 0)
        #expect(detector.progress(at: start.addingTimeInterval(60)) < 1)
    }

    @Test("A brief stir does not reset the streak")
    func briefStirIsTolerated() {
        var detector = SleepOnsetDetector(baseline: SleepBaseline(restingHeartRate: 58,
                                                                 typicalHRV: 50,
                                                                 sampleCount: 200))
        let start = date(23, 0)
        for second in stride(from: 0, through: 400, by: 20) {
            let timestamp = start.addingTimeInterval(TimeInterval(second))
            let stirring = second == 200
            detector.ingest(heartRate: 54,
                            movement: stirring ? 0.9 : 0.03,
                            timestamp: timestamp)
        }
        #expect(detector.phase != .awake)
    }

    @Test("Prolonged movement resets the streak")
    func prolongedMovementResets() {
        var detector = SleepOnsetDetector(baseline: SleepBaseline(restingHeartRate: 58,
                                                                 typicalHRV: 50,
                                                                 sampleCount: 200))
        let start = date(23, 0)
        detector.ingest(heartRate: 54, movement: 0.03, timestamp: start)
        detector.ingest(heartRate: 54, movement: 0.03, timestamp: start.addingTimeInterval(60))

        for second in stride(from: 120, through: 400, by: 20) {
            detector.ingest(heartRate: 54, movement: 0.9, timestamp: start.addingTimeInterval(TimeInterval(second)))
        }
        #expect(detector.phase == .awake)
        #expect(detector.quietSince == nil)
    }

    @Test("Resetting clears the streak")
    func resetClearsState() {
        var detector = SleepOnsetDetector(baseline: SleepBaseline(restingHeartRate: 58,
                                                                 typicalHRV: 50,
                                                                 sampleCount: 200))
        detector.ingest(heartRate: 54, movement: 0.02, timestamp: date(23, 0))
        detector.reset()

        #expect(detector.phase == .awake)
        #expect(detector.quietSince == nil)
    }

    @Test("The in-window configuration confirms faster than the default")
    func windowConfigurationIsFaster() {
        #expect(SleepOnsetDetector.Configuration.insideSleepWindow.sustainedInterval
                < SleepOnsetDetector.Configuration.default.sustainedInterval)
    }
}
