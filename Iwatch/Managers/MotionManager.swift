import Foundation
import CoreMotion

/// Wrist motion intensity, normalised to `0...1`.
///
/// Movement is what separates lying awake from actually sleeping, and REM's muscle
/// atonia from lighter stages. Until this existed every sample reported `movement: 0`,
/// which made the phone's REM segmentation treat the whole night as REM.
@MainActor
final class MotionManager: ObservableObject {
    static let shared = MotionManager()

    /// Acceleration in g above which a sample counts as fully "moving".
    private static let saturationG = 0.35
    /// Seconds of history folded into the published value.
    private static let smoothingWindow = 10

    @Published private(set) var movement: Double = 0

    private let motionManager = CMMotionManager()
    private var recent: [Double] = []

    private init() {}

    var isAvailable: Bool { motionManager.isAccelerometerAvailable }

    func start() {
        guard motionManager.isAccelerometerAvailable,
              !motionManager.isAccelerometerActive else { return }

        recent.removeAll()
        movement = 0
        motionManager.accelerometerUpdateInterval = 1.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            MainActor.assumeIsolated {
                self.ingest(data.acceleration)
            }
        }
    }

    func stop() {
        guard motionManager.isAccelerometerActive else { return }
        motionManager.stopAccelerometerUpdates()
        recent.removeAll()
        movement = 0
    }

    /// Gravity is always present in raw accelerometer data, so the deviation from
    /// 1 g is what actually represents wrist motion.
    private func ingest(_ acceleration: CMAcceleration) {
        let magnitude = sqrt(acceleration.x * acceleration.x
                             + acceleration.y * acceleration.y
                             + acceleration.z * acceleration.z)
        let deviation = abs(magnitude - 1.0)
        let normalised = min(max(deviation / Self.saturationG, 0), 1)

        recent.append(normalised)
        if recent.count > Self.smoothingWindow {
            recent.removeFirst(recent.count - Self.smoothingWindow)
        }
        movement = recent.reduce(0, +) / Double(recent.count)
    }
}
