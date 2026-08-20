import Foundation

/// First-run gating. Kept separate from the view so the decision is unit-testable.
enum OnboardingGate {
    /// `@AppStorage` key. Using UserDefaults here is what the privacy manifest's
    /// `CA92.1` required-reason declaration covers.
    static let storageKey = "hasCompletedOnboarding"

    nonisolated static func shouldPresent(hasCompletedOnboarding: Bool) -> Bool {
        !hasCompletedOnboarding
    }
}
