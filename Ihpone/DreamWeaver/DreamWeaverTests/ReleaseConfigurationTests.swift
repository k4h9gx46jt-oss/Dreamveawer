import Foundation
import Testing
@testable import DreamWeaver

@Suite("Release configuration")
struct ReleaseConfigurationTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DreamWeaverTests
            .deletingLastPathComponent() // DreamWeaver
            .deletingLastPathComponent() // Ihpone
            .deletingLastPathComponent() // Dreamweaver repo root
    }

    private func read(_ relativePath: String) throws -> String {
        let url = repoRoot.appending(path: relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("iOS target declares HealthKit usage descriptions")
    func iosTargetHasHealthUsageStrings() throws {
        let project = try read("Ihpone/DreamWeaver/DreamWeaver.xcodeproj/project.pbxproj")
        #expect(project.contains("INFOPLIST_KEY_NSHealthShareUsageDescription"))
        #expect(project.contains("INFOPLIST_KEY_NSHealthUpdateUsageDescription"))
    }

    @Test("iOS app and watch extension have entitlements wired")
    func targetsWireEntitlements() throws {
        let project = try read("Ihpone/DreamWeaver/DreamWeaver.xcodeproj/project.pbxproj")
        #expect(project.contains("CODE_SIGN_ENTITLEMENTS = DreamWeaver/DreamWeaver.entitlements;"))
        #expect(project.contains("CODE_SIGN_ENTITLEMENTS = \"../../Iwatch/WatchExtension.entitlements\";"))
    }

    @Test("iOS app entitlements enable HealthKit")
    func iosEntitlementsEnableHealthKit() throws {
        let entitlements = try read("Ihpone/DreamWeaver/DreamWeaver/DreamWeaver.entitlements")
        #expect(entitlements.contains("<key>com.apple.developer.healthkit</key>"))
        #expect(entitlements.contains("<true/>"))
    }

    @Test("watch extension entitlements enable HealthKit")
    func watchEntitlementsEnableHealthKit() throws {
        let entitlements = try read("Iwatch/WatchExtension.entitlements")
        #expect(entitlements.contains("<key>com.apple.developer.healthkit</key>"))
        #expect(entitlements.contains("<true/>"))
    }

    @Test("watch extension plist keeps HealthKit usage strings")
    func watchExtensionPlistHasHealthUsageStrings() throws {
        let plist = try read("Iwatch/WatchExtension-Info.plist")
        #expect(plist.contains("<key>NSHealthShareUsageDescription</key>"))
        #expect(plist.contains("<key>NSHealthUpdateUsageDescription</key>"))
    }

    @Test("watch extension plist declares workout background processing")
    func watchExtensionPlistHasWorkoutBackgroundMode() throws {
        let plist = try read("Iwatch/WatchExtension-Info.plist")
        #expect(plist.contains("<key>WKBackgroundModes</key>"))
        #expect(plist.contains("<string>workout-processing</string>"))
    }
}
