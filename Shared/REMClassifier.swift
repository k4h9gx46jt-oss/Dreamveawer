import Foundation

/// The sleep stage the watch reports for a single sample.
enum REMState: String, Codable {
    case light
    case deep
    case rem
}

/// A contiguous stretch classified as REM.
struct REMWindow: Identifiable, Codable, Equatable {
    let id: UUID
    let start: Date
    let end: Date

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func extended(to date: Date) -> REMWindow {
        REMWindow(id: id, start: start, end: date)
    }
}

/// Pure sleep-stage classification, shared by the watch runtime and the test suite.
///
/// Kept free of HealthKit and WatchKit so the rules can be verified without a device.
struct REMClassifier {
    /// Below this heart rate the sleeper is treated as being in deep sleep.
    static let deepSleepMaxHeartRate: Double = 50
    /// REM is only considered inside this heart-rate band.
    static let remHeartRateRange: ClosedRange<Double> = 50...75
    /// Variability under this value rules REM out even inside the band.
    static let minimumREMHeartRateVariability: Double = 35
    /// How long a freshly opened REM window is assumed to run.
    static let initialWindowDuration: TimeInterval = 60

    private(set) var state: REMState = .light
    private(set) var windows: [REMWindow] = []

    init(state: REMState = .light, windows: [REMWindow] = []) {
        self.state = state
        self.windows = windows
    }

    /// Classifies a reading in isolation, without touching any accumulated state.
    static func classify(heartRate: Double, heartRateVariability: Double) -> REMState {
        if heartRate < deepSleepMaxHeartRate {
            return .deep
        }
        if remHeartRateRange.contains(heartRate),
           heartRateVariability >= minimumREMHeartRateVariability {
            return .rem
        }
        return .light
    }

    /// Advances the classifier, opening a REM window on entry and extending it while REM continues.
    @discardableResult
    mutating func ingest(heartRate: Double,
                         heartRateVariability: Double,
                         timestamp: Date) -> REMState {
        let next = Self.classify(heartRate: heartRate, heartRateVariability: heartRateVariability)

        if next == .rem {
            if state == .rem, let open = windows.popLast() {
                windows.append(open.extended(to: timestamp))
            } else {
                windows.append(REMWindow(start: timestamp,
                                         end: timestamp.addingTimeInterval(Self.initialWindowDuration)))
            }
        }

        state = next
        return next
    }

    var totalREMDuration: TimeInterval {
        windows.reduce(0) { $0 + $1.duration }
    }
}
