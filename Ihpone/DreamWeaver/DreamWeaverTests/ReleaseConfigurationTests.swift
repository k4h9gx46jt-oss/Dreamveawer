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

    private func exists(_ relativePath: String) -> Bool {
        let url = repoRoot.appending(path: relativePath)
        return FileManager.default.fileExists(atPath: url.path)
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
        #expect(plist.contains("<key>UIBackgroundModes</key>"))
        #expect(plist.contains("<key>WKBackgroundModes</key>"))
        #expect(plist.contains("<string>workout-processing</string>"))
    }

    @Test("iOS app bundles a PrivacyInfo manifest")
    func appHasPrivacyManifest() throws {
        let manifestPath = "Ihpone/DreamWeaver/DreamWeaver/PrivacyInfo.xcprivacy"
        #expect(exists(manifestPath))

        let manifest = try read(manifestPath)
        #expect(manifest.contains("<key>NSPrivacyTracking</key>"))
        #expect(manifest.contains("<key>NSPrivacyCollectedDataTypes</key>"))
        #expect(manifest.contains("<key>NSPrivacyAccessedAPITypes</key>"))
    }

    @Test("Privacy manifest declares the UserDefaults required-reason API")
    func manifestDeclaresUserDefaultsReason() throws {
        let manifest = try read("Ihpone/DreamWeaver/DreamWeaver/PrivacyInfo.xcprivacy")
        #expect(manifest.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        #expect(manifest.contains("CA92.1"))
    }

    @Test("Privacy manifest declares Health & Fitness data, unlinked and untracked")
    func manifestDeclaresHealthData() throws {
        let manifest = try read("Ihpone/DreamWeaver/DreamWeaver/PrivacyInfo.xcprivacy")
        #expect(manifest.contains("NSPrivacyCollectedDataTypeHealth"))
        #expect(manifest.contains("NSPrivacyCollectedDataTypeFitness"))
        #expect(manifest.contains("NSPrivacyCollectedDataTypePurposeAppFunctionality"))
        // The product promise is on-device only: nothing is tracked or linked to identity.
        #expect(!manifest.contains("<true/>"))
    }

    @Test("iOS app declares the audio background mode for soundtrack playback")
    func iosAppDeclaresAudioBackgroundMode() throws {
        let plistPath = "Ihpone/DreamWeaver/Info.plist"
        #expect(exists(plistPath))

        let plist = try read(plistPath)
        #expect(plist.contains("<key>UIBackgroundModes</key>"))
        #expect(plist.contains("<string>audio</string>"))
    }

    @Test("iOS target wires the physical Info.plist")
    func iosTargetWiresInfoPlist() throws {
        let project = try read("Ihpone/DreamWeaver/DreamWeaver.xcodeproj/project.pbxproj")
        #expect(project.contains("INFOPLIST_FILE = Info.plist;"))
    }

    @Test("template Item.swift is removed from app sources")
    func templateItemSwiftIsRemoved() {
        #expect(!exists("Ihpone/DreamWeaver/DreamWeaver/Item.swift"))
    }
}
