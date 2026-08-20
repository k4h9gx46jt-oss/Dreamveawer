import Foundation
import HealthKit
import Testing
@testable import DreamWeaver

@Suite("Health access state")
struct HealthAccessStateTests {

    @Test("No Health support resolves to unavailable regardless of status")
    func unavailableWhenNoHealth() {
        #expect(HealthAccessState.resolve(isAvailable: false, requestStatus: .shouldRequest) == .unavailable)
        #expect(HealthAccessState.resolve(isAvailable: false, requestStatus: .unnecessary) == .unavailable)
    }

    @Test("Should-request maps to needsPermission")
    func needsPermission() {
        #expect(HealthAccessState.resolve(isAvailable: true, requestStatus: .shouldRequest) == .needsPermission)
    }

    @Test("Unnecessary maps to ready")
    func ready() {
        #expect(HealthAccessState.resolve(isAvailable: true, requestStatus: .unnecessary) == .ready)
    }

    @Test("Unknown status maps to unknown")
    func unknown() {
        #expect(HealthAccessState.resolve(isAvailable: true, requestStatus: .unknown) == .unknown)
    }

    @Test("Ready and unknown show no banner")
    func noDescriptorWhenFine() {
        #expect(HealthAccessState.ready.descriptor == nil)
        #expect(HealthAccessState.unknown.descriptor == nil)
    }

    @Test("Unavailable offers a Settings deep link")
    func unavailableDescriptor() throws {
        let descriptor = try #require(HealthAccessState.unavailable.descriptor)
        #expect(descriptor.opensSettings)
        #expect(!descriptor.title.isEmpty)
        #expect(!descriptor.message.isEmpty)
    }

    @Test("Needs-permission asks to continue, not to open Settings")
    func needsPermissionDescriptor() throws {
        let descriptor = try #require(HealthAccessState.needsPermission.descriptor)
        #expect(!descriptor.opensSettings)
        #expect(!descriptor.actionTitle.isEmpty)
    }
}
