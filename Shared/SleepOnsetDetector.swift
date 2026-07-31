import Foundation

/// Decides when a sleeper has actually fallen asleep so Dream Mode can arm itself.
///
/// Two independent signals have to agree for long enough: the wrist has gone quiet
/// and the heart rate has settled toward its resting floor. Requiring both avoids
/// arming a session while someone is lying still reading in bed.
/// Kept free of HealthKit so the rules can be verified without a device.
struct SleepOnsetDetector {
    enum Phase: String, Codable {
        /// Moving, or heart rate still well above resting.
        case awake
        /// Quiet and settling, but not yet for long enough.
        case settling
        /// Sustained quiet — Dream Mode can start.
        case asleep
    }

    struct Configuration: Equatable {
        /// Motion at or above this counts as being awake.
        var quietMovementCeiling: Double
        /// How far below the resting baseline the heart rate must fall.
        var heartRateMargin: Double
        /// How long both signals must hold before onset is declared.
        var sustainedInterval: TimeInterval
        /// A single blip shorter than this does not reset the streak.
        var toleratedInterruption: TimeInterval

        init(quietMovementCeiling: Double = 0.2,
             heartRateMargin: Double = 3,
             sustainedInterval: TimeInterval = 8 * 60,
             toleratedInterruption: TimeInterval = 45) {
            self.quietMovementCeiling = quietMovementCeiling
            self.heartRateMargin = heartRateMargin
            self.sustainedInterval = sustainedInterval
            self.toleratedInterruption = toleratedInterruption
        }

        static let `default` = Configuration()

        /// Shorter confirmation for when the phone's sleep schedule already says
        /// it is bedtime, so the two signals only need to corroborate it.
        static let insideSleepWindow = Configuration(sustainedInterval: 3 * 60)
    }

    let configuration: Configuration
    private(set) var phase: Phase = .awake
    private(set) var baseline: SleepBaseline
    private(set) var quietSince: Date?
    private var lastDisturbance: Date?

    init(configuration: Configuration = .default,
         baseline: SleepBaseline = .population) {
        self.configuration = configuration
        self.baseline = baseline
    }

    @discardableResult
    mutating func ingest(heartRate: Double,
                         heartRateVariability: Double = 0,
                         movement: Double,
                         timestamp: Date) -> Phase {
        baseline.ingest(heartRate: heartRate, heartRateVariability: heartRateVariability)

        let restingCeiling = baseline.restingHeartRate + configuration.heartRateMargin
        let isQuiet = movement < configuration.quietMovementCeiling && heartRate <= restingCeiling

        guard isQuiet else {
            registerDisturbance(at: timestamp)
            return phase
        }

        lastDisturbance = nil
        let start = quietSince ?? timestamp
        quietSince = start

        if timestamp.timeIntervalSince(start) >= configuration.sustainedInterval {
            phase = .asleep
        } else if phase != .asleep {
            phase = .settling
        }
        return phase
    }

    /// How close the sleeper is to the onset threshold, for progress UI.
    func progress(at date: Date) -> Double {
        guard phase != .asleep else { return 1 }
        guard let quietSince, configuration.sustainedInterval > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(quietSince)
        return min(max(elapsed / configuration.sustainedInterval, 0), 1)
    }

    mutating func reset() {
        phase = .awake
        quietSince = nil
        lastDisturbance = nil
    }

    /// Brief movement is normal during sleep, so the streak only breaks once a
    /// disturbance has persisted past `toleratedInterruption`.
    private mutating func registerDisturbance(at timestamp: Date) {
        guard let first = lastDisturbance else {
            lastDisturbance = timestamp
            return
        }
        guard timestamp.timeIntervalSince(first) >= configuration.toleratedInterruption else {
            return
        }
        phase = .awake
        quietSince = nil
        lastDisturbance = timestamp
    }
}
