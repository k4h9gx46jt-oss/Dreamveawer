import Foundation

/// The sleep stage the watch reports for a single sample.
enum REMState: String, Codable {
    case awake
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

/// Staging thresholds fitted to one sleeper.
///
/// Fixed population thresholds mis-stage most people: an endurance athlete resting
/// at 42 bpm never leaves "deep", and someone resting at 72 bpm never enters it.
/// This tracks the sleeper's own overnight floor and variability instead.
struct SleepBaseline: Codable, Equatable {
    /// Readings needed before the learned thresholds are trusted over the population defaults.
    static let warmUpSamples = 60

    static let population = SleepBaseline()

    private(set) var restingHeartRate: Double
    private(set) var typicalHRV: Double
    private(set) var sampleCount: Int

    init(restingHeartRate: Double = 60, typicalHRV: Double = 45, sampleCount: Int = 0) {
        self.restingHeartRate = restingHeartRate
        self.typicalHRV = typicalHRV
        self.sampleCount = sampleCount
    }

    var isWarmedUp: Bool { sampleCount >= Self.warmUpSamples }

    /// Falls quickly toward new lows and rises very slowly, approximating the
    /// night's resting floor without letting one spike drag the baseline up.
    mutating func ingest(heartRate: Double, heartRateVariability: Double) {
        guard heartRate.isFinite, heartRate > 0 else { return }
        let descentRate = 0.05
        let ascentRate = 0.001
        let rate = heartRate < restingHeartRate ? descentRate : ascentRate
        restingHeartRate += (heartRate - restingHeartRate) * rate

        if heartRateVariability.isFinite, heartRateVariability > 0 {
            typicalHRV += (heartRateVariability - typicalHRV) * 0.02
        }
        sampleCount += 1
    }

    var deepSleepMaxHeartRate: Double {
        isWarmedUp ? restingHeartRate * 0.97 : REMClassifier.deepSleepMaxHeartRate
    }

    var remHeartRateRange: ClosedRange<Double> {
        guard isWarmedUp else { return REMClassifier.remHeartRateRange }
        let lower = restingHeartRate * 0.97
        return lower...(restingHeartRate * 1.28)
    }

    var minimumREMHeartRateVariability: Double {
        isWarmedUp ? typicalHRV * 0.75 : REMClassifier.minimumREMHeartRateVariability
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
    /// Sustained motion above this is incompatible with any sleep stage.
    static let awakeMovementThreshold: Double = 0.55
    /// REM comes with muscle atonia, so movement above this rules it out.
    static let remMovementCeiling: Double = 0.25

    struct Configuration: Equatable {
        /// Majority vote depth. `1` classifies each reading on its own.
        var smoothingDepth: Int
        /// Whether thresholds adapt to the sleeper's own readings.
        var adaptiveBaseline: Bool
        /// Whether movement can veto REM and force `.awake`.
        var movementAware: Bool

        init(smoothingDepth: Int = 1, adaptiveBaseline: Bool = false, movementAware: Bool = false) {
            self.smoothingDepth = max(1, smoothingDepth)
            self.adaptiveBaseline = adaptiveBaseline
            self.movementAware = movementAware
        }

        /// Fixed thresholds, one reading at a time.
        static let legacy = Configuration()

        /// Personalised thresholds with motion vetoes and a ~7 s majority vote,
        /// which stops 1 Hz sampling from flipping the reported stage every second.
        static let overnight = Configuration(smoothingDepth: 7,
                                             adaptiveBaseline: true,
                                             movementAware: true)
    }

    let configuration: Configuration
    private(set) var baseline: SleepBaseline
    private(set) var state: REMState = .light
    private(set) var windows: [REMWindow] = []
    private var recent: [REMState] = []

    init(state: REMState = .light,
         windows: [REMWindow] = [],
         configuration: Configuration = .legacy,
         baseline: SleepBaseline = .population) {
        self.state = state
        self.windows = windows
        self.configuration = configuration
        self.baseline = baseline
    }

    /// Classifies a reading in isolation, without touching any accumulated state.
    static func classify(heartRate: Double, heartRateVariability: Double) -> REMState {
        classify(heartRate: heartRate,
                 heartRateVariability: heartRateVariability,
                 movement: nil,
                 baseline: nil)
    }

    /// Classifies a reading against a sleeper's own thresholds, optionally letting
    /// movement veto the result.
    static func classify(heartRate: Double,
                         heartRateVariability: Double,
                         movement: Double?,
                         baseline: SleepBaseline?) -> REMState {
        if let movement, movement >= awakeMovementThreshold {
            return .awake
        }

        let deepCeiling = baseline?.deepSleepMaxHeartRate ?? deepSleepMaxHeartRate
        let remBand = baseline?.remHeartRateRange ?? remHeartRateRange
        let hrvFloor = baseline?.minimumREMHeartRateVariability ?? minimumREMHeartRateVariability

        if heartRate < deepCeiling {
            return .deep
        }
        if remBand.contains(heartRate), heartRateVariability >= hrvFloor {
            if let movement, movement > remMovementCeiling {
                return .light
            }
            return .rem
        }
        return .light
    }

    /// Advances the classifier, opening a REM window on entry and extending it while REM continues.
    @discardableResult
    mutating func ingest(heartRate: Double,
                         heartRateVariability: Double,
                         timestamp: Date) -> REMState {
        ingest(heartRate: heartRate,
               heartRateVariability: heartRateVariability,
               movement: nil,
               timestamp: timestamp)
    }

    /// Advances the classifier using a reading that also carries motion intensity.
    @discardableResult
    mutating func ingest(heartRate: Double,
                         heartRateVariability: Double,
                         movement: Double?,
                         timestamp: Date) -> REMState {
        if configuration.adaptiveBaseline {
            baseline.ingest(heartRate: heartRate, heartRateVariability: heartRateVariability)
        }

        let raw = Self.classify(heartRate: heartRate,
                                heartRateVariability: heartRateVariability,
                                movement: configuration.movementAware ? movement : nil,
                                baseline: configuration.adaptiveBaseline ? baseline : nil)
        let next = smoothed(raw)

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

    /// Majority vote over the most recent readings, breaking ties in favour of
    /// staying put so the reported stage does not oscillate.
    private mutating func smoothed(_ raw: REMState) -> REMState {
        guard configuration.smoothingDepth > 1 else { return raw }

        recent.append(raw)
        if recent.count > configuration.smoothingDepth {
            recent.removeFirst(recent.count - configuration.smoothingDepth)
        }
        guard recent.count == configuration.smoothingDepth else { return state }

        var tally: [REMState: Int] = [:]
        for entry in recent {
            tally[entry, default: 0] += 1
        }
        guard let best = tally.max(by: { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return rhs.key == state
        }) else {
            return state
        }
        return best.key
    }
}
