import Foundation
import Combine
import SwiftUI
import HealthKit

/// User-facing summary of whether DreamWeaver can read Health data.
///
/// HealthKit never reveals whether *read* access was granted or denied, so the
/// most we can honestly express is "the permission sheet still needs to be shown"
/// versus "it has been handled".
enum HealthAccessState: Equatable {
    case unknown
    /// The device cannot provide Health data at all (for example, iPad).
    case unavailable
    /// The Health permission sheet has not yet been presented/granted.
    case needsPermission
    /// Permission has been handled — proceed.
    case ready

    nonisolated static func resolve(isAvailable: Bool,
                                    requestStatus: HKAuthorizationRequestStatus) -> HealthAccessState {
        guard isAvailable else { return .unavailable }
        switch requestStatus {
        case .shouldRequest: return .needsPermission
        case .unnecessary: return .ready
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }

    struct Descriptor: Equatable {
        let title: String
        let message: String
        let actionTitle: String
        let opensSettings: Bool
    }

    /// The banner content for a state, or `nil` when nothing needs to be shown.
    nonisolated var descriptor: Descriptor? {
        switch self {
        case .ready, .unknown:
            return nil
        case .unavailable:
            return Descriptor(
                title: "Health data unavailable",
                message: "This device can’t provide Health data. Wear your Apple Watch with DreamWeaver to capture your nights.",
                actionTitle: "Open Settings",
                opensSettings: true
            )
        case .needsPermission:
            return Descriptor(
                title: "Allow Health access",
                message: "DreamWeaver turns your heart rate, HRV and sleep into a dream film — entirely on your device. Grant Health access to begin.",
                actionTitle: "Continue",
                opensSettings: false
            )
        }
    }
}

@MainActor
final class HealthAccessModel: ObservableObject {
    @Published private(set) var state: HealthAccessState = .unknown

    private let manager: HealthKitManager

    init(manager: HealthKitManager = HealthKitManager()) {
        self.manager = manager
    }

    func refresh() async {
        let status = await manager.requestStatus()
        state = HealthAccessState.resolve(isAvailable: manager.isHealthDataAvailable,
                                          requestStatus: status)
    }

    /// Presents the Health permission sheet, then re-reads the resulting state.
    func request() async {
        try? await manager.requestAuthorization()
        await refresh()
    }

    func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
