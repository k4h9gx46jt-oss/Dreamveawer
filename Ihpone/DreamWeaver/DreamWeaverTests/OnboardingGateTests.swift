import Foundation
import Testing
@testable import DreamWeaver

@Suite("Onboarding gate")
struct OnboardingGateTests {

    @Test("First run presents onboarding")
    func presentsOnFirstRun() {
        #expect(OnboardingGate.shouldPresent(hasCompletedOnboarding: false))
    }

    @Test("Completed onboarding is not shown again")
    func hiddenAfterCompletion() {
        #expect(!OnboardingGate.shouldPresent(hasCompletedOnboarding: true))
    }

    @Test("Storage key is stable")
    func storageKeyStable() {
        // Changing this silently re-onboards every existing user, so it is pinned.
        #expect(OnboardingGate.storageKey == "hasCompletedOnboarding")
    }
}
