import Foundation

/// A recurring nightly sleep window, e.g. 22:00 → 06:00.
///
/// Mirrors the schedule the user has already configured in the Health app or Sleep
/// Focus, so Dream Mode can arm itself instead of relying on a button press.
/// Kept free of HealthKit so the wrap-around arithmetic can be tested directly.
struct SleepWindow: Codable, Equatable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    static let `default` = SleepWindow(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

    init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = Self.wrapHour(startHour)
        self.startMinute = min(max(startMinute, 0), 59)
        self.endHour = Self.wrapHour(endHour)
        self.endMinute = min(max(endMinute, 0), 59)
    }

    private static func wrapHour(_ hour: Int) -> Int {
        let wrapped = hour % 24
        return wrapped < 0 ? wrapped + 24 : wrapped
    }

    var startMinuteOfDay: Int { startHour * 60 + startMinute }
    var endMinuteOfDay: Int { endHour * 60 + endMinute }

    /// True for the common case where bedtime is before midnight and wake-up after it.
    var crossesMidnight: Bool { endMinuteOfDay <= startMinuteOfDay }

    var duration: TimeInterval {
        let minutes = crossesMidnight
            ? (1440 - startMinuteOfDay) + endMinuteOfDay
            : endMinuteOfDay - startMinuteOfDay
        return TimeInterval(minutes * 60)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }
        let now = hour * 60 + minute

        if crossesMidnight {
            return now >= startMinuteOfDay || now < endMinuteOfDay
        }
        return now >= startMinuteOfDay && now < endMinuteOfDay
    }

    /// The next bedtime at or after `date`.
    func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        nextOccurrence(hour: startHour, minute: startMinute, after: date, calendar: calendar)
    }

    /// The next wake-up time at or after `date`.
    func nextEnd(after date: Date, calendar: Calendar = .current) -> Date? {
        nextOccurrence(hour: endHour, minute: endMinute, after: date, calendar: calendar)
    }

    private func nextOccurrence(hour: Int,
                                minute: Int,
                                after date: Date,
                                calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.nextDate(after: date,
                                 matching: components,
                                 matchingPolicy: .nextTimePreservingSmallerComponents)
    }

    /// Averages observed sleep intervals into a window.
    ///
    /// Times are averaged as points on a circle, so 23:50 and 00:10 average to
    /// midnight rather than to noon.
    static func inferred(from intervals: [DateInterval],
                         calendar: Calendar = .current) -> SleepWindow? {
        guard !intervals.isEmpty else { return nil }

        let starts = intervals.map(\.start)
        let ends = intervals.map(\.end)
        guard let start = circularMean(of: starts, calendar: calendar),
              let end = circularMean(of: ends, calendar: calendar) else {
            return nil
        }

        return SleepWindow(startHour: start.hour,
                           startMinute: start.minute,
                           endHour: end.hour,
                           endMinute: end.minute)
    }

    private static func circularMean(of dates: [Date],
                                     calendar: Calendar) -> (hour: Int, minute: Int)? {
        var x = 0.0
        var y = 0.0
        var counted = 0

        for date in dates {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            guard let hour = components.hour, let minute = components.minute else { continue }
            let angle = Double(hour * 60 + minute) / 1440 * 2 * .pi
            x += cos(angle)
            y += sin(angle)
            counted += 1
        }

        guard counted > 0, x != 0 || y != 0 else { return nil }

        var angle = atan2(y / Double(counted), x / Double(counted))
        if angle < 0 { angle += 2 * .pi }

        let totalMinutes = Int((angle / (2 * .pi) * 1440).rounded()) % 1440
        return (hour: totalMinutes / 60, minute: totalMinutes % 60)
    }
}
