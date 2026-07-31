import Foundation
import HealthKit
import WatchKit

/// Starts Dream Mode without a button press.
///
/// Two independent triggers, either of which is enough:
///
/// 1. **The system says you are asleep.** watchOS writes `sleepAnalysis` samples
///    once its own sleep detection fires. An observer query wakes the extension
///    and arms a session.
/// 2. **Your own readings say you are asleep.** Inside the configured sleep window
///    a `SleepOnsetDetector` watches heart rate and wrist motion, so a session can
///    begin even if the system has not committed to a sleep sample yet.
///
/// The sleep window is inferred from the schedule already configured in the Health
/// app, so the user never has to enter their bedtime twice.
@MainActor
final class SleepAutoStartMonitor: ObservableObject {
    static let shared = SleepAutoStartMonitor()

    private enum Keys {
        static let enabled = "dw.autostart.enabled"
        static let window = "dw.autostart.window"
    }

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            isEnabled ? start() : stop()
        }
    }

    @Published private(set) var window: SleepWindow
    @Published private(set) var onsetProgress: Double = 0
    @Published private(set) var lastTrigger: String?

    private let healthStore = HKHealthStore()
    private let defaults = UserDefaults.standard
    private var observerQuery: HKObserverQuery?
    private var evaluationTimer: Timer?
    private var detector = SleepOnsetDetector()
    private var heartRateQuery: HKAnchoredObjectQuery?

    private init() {
        let storedEnabled = defaults.object(forKey: Keys.enabled) as? Bool
        isEnabled = storedEnabled ?? true

        if let data = defaults.data(forKey: Keys.window),
           let decoded = try? JSONDecoder().decode(SleepWindow.self, from: data) {
            window = decoded
        } else {
            window = .default
        }
    }

    var isInsideWindow: Bool { window.contains(Date()) }

    func activate() {
        guard isEnabled else { return }
        start()
    }

    // MARK: - Lifecycle

    private func start() {
        Task {
            await refreshWindowFromHealthKit()
            startSleepObserver()
            startWindowEvaluation()
        }
    }

    private func stop() {
        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
        if let heartRateQuery {
            healthStore.stop(heartRateQuery)
            self.heartRateQuery = nil
        }
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        detector.reset()
        onsetProgress = 0
    }

    // MARK: - Trigger 1 — the system reports sleep

    private func startSleepObserver() {
        guard observerQuery == nil,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completion, error in
            defer { completion() }
            guard error == nil else { return }
            Task { @MainActor in
                await self?.handleSleepSampleChange()
            }
        }
        healthStore.execute(query)
        observerQuery = query

        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { _, _ in }
    }

    private func handleSleepSampleChange() async {
        guard isEnabled, !WorkoutManager.shared.isTracking else { return }
        guard await isSystemReportingSleep() else { return }
        trigger(reason: "Apple Watch detected sleep")
    }

    /// True when a sleep sample overlapping the last few minutes says the wearer is asleep.
    private func isSystemReportingSleep() async -> Bool {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return false }

        let start = Date().addingTimeInterval(-15 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictEndDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType,
                                      predicate: predicate,
                                      limit: 10,
                                      sortDescriptors: sort) { _, results, _ in
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }

        return samples.contains { Self.indicatesAsleep($0.value) }
    }

    private static func indicatesAsleep(_ rawValue: Int) -> Bool {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: rawValue) else { return false }
        switch value {
        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
            return true
        case .inBed, .awake:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Trigger 2 — our own readings inside the sleep window

    private func startWindowEvaluation() {
        evaluationTimer?.invalidate()
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateWindow()
            }
        }
        evaluateWindow()
    }

    private func evaluateWindow() {
        guard isEnabled, !WorkoutManager.shared.isTracking else {
            onsetProgress = 0
            return
        }
        guard isInsideWindow else {
            detector.reset()
            onsetProgress = 0
            stopHeartRateSampling()
            return
        }
        startHeartRateSampling()
        onsetProgress = detector.progress(at: Date())
        if detector.phase == .asleep {
            trigger(reason: "Sleep schedule and biosignals agree")
        }
    }

    /// Only runs inside the sleep window, so the wrist is not being polled all day.
    private func startHeartRateSampling() {
        guard heartRateQuery == nil,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        detector = SleepOnsetDetector(configuration: .insideSleepWindow)

        let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            [weak self] _, samples, _, _, _ in
            guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }
            Task { @MainActor in
                self?.ingest(quantitySamples)
            }
        }

        let query = HKAnchoredObjectQuery(type: heartRateType,
                                          predicate: nil,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit,
                                          resultsHandler: handler)
        query.updateHandler = handler
        healthStore.execute(query)
        heartRateQuery = query
    }

    private func stopHeartRateSampling() {
        guard let heartRateQuery else { return }
        healthStore.stop(heartRateQuery)
        self.heartRateQuery = nil
    }

    private func ingest(_ samples: [HKQuantitySample]) {
        let unit = HKUnit.count().unitDivided(by: .minute())
        let movement = MotionManager.shared.movement

        for sample in samples {
            detector.ingest(heartRate: sample.quantity.doubleValue(for: unit),
                            movement: movement,
                            timestamp: sample.endDate)
        }
        onsetProgress = detector.progress(at: Date())

        if detector.phase == .asleep {
            trigger(reason: "Sleep schedule and biosignals agree")
        }
    }

    // MARK: - Arming

    private func trigger(reason: String) {
        guard !WorkoutManager.shared.isTracking else { return }
        lastTrigger = reason
        detector.reset()
        onsetProgress = 0
        WKInterfaceDevice.current().play(.notification)
        WorkoutManager.shared.start(automatically: true)
    }

    // MARK: - Sleep window

    /// Reads the schedule the user already configured in the Health app rather
    /// than asking them to enter a bedtime again.
    func refreshWindowFromHealthKit() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: sort) { _, results, _ in
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }

        let intervals = Self.nightlyIntervals(from: samples)
        guard let inferred = SleepWindow.inferred(from: intervals) else { return }
        update(window: inferred)
    }

    func update(window newValue: SleepWindow) {
        window = newValue
        if let data = try? JSONEncoder().encode(newValue) {
            defaults.set(data, forKey: Keys.window)
        }
    }

    /// Collapses HealthKit's fragmented sleep samples into one interval per night.
    static func nightlyIntervals(from samples: [HKCategorySample]) -> [DateInterval] {
        let relevant = samples
            .filter { indicatesAsleep($0.value) || $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
            .sorted { $0.startDate < $1.startDate }
        guard !relevant.isEmpty else { return [] }

        var intervals: [DateInterval] = []
        var currentStart = relevant[0].startDate
        var currentEnd = relevant[0].endDate
        let gapTolerance: TimeInterval = 2 * 3600

        for sample in relevant.dropFirst() {
            if sample.startDate.timeIntervalSince(currentEnd) <= gapTolerance {
                currentEnd = max(currentEnd, sample.endDate)
            } else {
                intervals.append(DateInterval(start: currentStart, end: currentEnd))
                currentStart = sample.startDate
                currentEnd = sample.endDate
            }
        }
        intervals.append(DateInterval(start: currentStart, end: currentEnd))

        // A 20-minute nap says nothing useful about a bedtime schedule.
        return intervals.filter { $0.duration >= 3 * 3600 }
    }
}
