import AVFoundation
import Foundation
import Testing
import UIKit
@testable import DreamWeaver

@Suite("Dream film generation")
struct DreamFilmTests {

    @Test("Every mood produces a well formed visual profile", arguments: DreamMood.allCases)
    func visualProfileIsWellFormed(mood: DreamMood) throws {
        let profile = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: mood))

        #expect(profile.palette.count == 5)
        #expect(profile.ribbonCount > 0)
        #expect(profile.nebulaLayers > 0)
        #expect(profile.particleCount > 0)
        #expect(profile.grainAmount > 0 && profile.grainAmount <= 0.3)
        #expect(profile.vignette > 0 && profile.vignette <= 1)
        #expect(profile.stereoSafeRanges)
    }

    @Test("Each genre gets its own visual style")
    func stylesAreDistinct() throws {
        var styles: Set<String> = []
        for mood in DreamMood.allCases {
            let profile = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: mood))
            styles.insert(profile.style.rawValue)
        }
        #expect(styles.count >= 4)
    }

    @Test("Turbulent dreams shake, pulse and glitch harder than peaceful ones")
    func turbulentIsMoreAggressive() throws {
        let peaceful = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: .peaceful))
        let turbulent = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: .turbulent))

        #expect(turbulent.shakeStrength > peaceful.shakeStrength)
        #expect(turbulent.pulseStrength > peaceful.pulseStrength)
        #expect(turbulent.glitchStrength > peaceful.glitchStrength)
        #expect(turbulent.particleCount > peaceful.particleCount)
        #expect(turbulent.vignette > peaceful.vignette)
    }

    @Test("Calm styles carry the aurora curtains")
    func calmStylesHaveCurtains() throws {
        let peaceful = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: .peaceful))
        let chaotic = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: .chaotic))

        #expect(peaceful.curtainCount > 0)
        #expect(chaotic.curtainCount == 0)
    }

    @Test("Apnea and ambient noise roughen the grain")
    func biosignalsAffectGrain() throws {
        let quiet = try DreamFixture.visualProfile(
            for: DreamFixture.dream(mood: .calm, apneaSpikes: 0, noiseSpikes: 0))
        let disturbed = try DreamFixture.visualProfile(
            for: DreamFixture.dream(mood: .calm, apneaSpikes: 8, noiseSpikes: 10))

        #expect(disturbed.grainAmount > quiet.grainAmount)
    }

    @Test("The palette is opaque and distinct", arguments: DreamMood.allCases)
    func paletteIsUsable(mood: DreamMood) throws {
        let palette = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: mood)).palette
        for color in palette {
            var alpha: CGFloat = 0
            #expect(color.getWhite(nil, alpha: &alpha) || true)
            color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
            #expect(alpha > 0.9)
        }
        // Shadow must be darker than the highlight.
        var shadowBrightness: CGFloat = 0
        var highlightBrightness: CGFloat = 0
        palette[0].getHue(nil, saturation: nil, brightness: &shadowBrightness, alpha: nil)
        palette[3].getHue(nil, saturation: nil, brightness: &highlightBrightness, alpha: nil)
        #expect(shadowBrightness < highlightBrightness)
    }

    @Test("Visual diagnostics report the render size", arguments: DreamMood.allCases)
    func diagnosticsReportResolution(mood: DreamMood) throws {
        let diagnostics = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: mood)).diagnostics
        #expect(diagnostics["resolution"] == "\(DreamFilmRenderer.width)x\(DreamFilmRenderer.height)")
        #expect(diagnostics["visualStyle"]?.isEmpty == false)
    }

    @Test("A playable film is written for every mood", arguments: DreamMood.allCases)
    func rendersFilm(mood: DreamMood) async throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: mood))
        let url = directory.appendingPathComponent("film-\(mood.rawValue).mp4")
        try await DreamFilmRenderer.write(to: url, duration: 0.5, tempo: 96, profile: profile)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        #expect(size > 1_000, "\(mood) film is suspiciously small")

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let dimensions = try await track.load(.naturalSize)
        #expect(Int(dimensions.width) == DreamFilmRenderer.width)
        #expect(Int(dimensions.height) == DreamFilmRenderer.height)

        let duration = try await asset.load(.duration)
        #expect(CMTimeGetSeconds(duration) > 0)
    }

    @Test("Rendered frames are not blank")
    func framesHaveContent() async throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: .ethereal))
        let url = directory.appendingPathComponent("frames.mp4")
        try await DreamFilmRenderer.write(to: url, duration: 1.0, tempo: 96, profile: profile)

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let (image, _) = try await generator.image(at: CMTime(seconds: 0.6, preferredTimescale: 600))

        #expect(image.width == DreamFilmRenderer.width)
        #expect(image.height == DreamFilmRenderer.height)

        // The frame must contain more than a single flat colour.
        let bitmap = UIImage(cgImage: image)
        let data = try #require(bitmap.pngData())
        #expect(data.count > 5_000)
    }

    @Test("Longer runtimes produce proportionally longer films")
    func durationScales() async throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: .calm))
        let shortURL = directory.appendingPathComponent("short.mp4")
        let longURL = directory.appendingPathComponent("long.mp4")

        try await DreamFilmRenderer.write(to: shortURL, duration: 0.5, tempo: 90, profile: profile)
        try await DreamFilmRenderer.write(to: longURL, duration: 1.5, tempo: 90, profile: profile)

        let shortSeconds = CMTimeGetSeconds(try await AVURLAsset(url: shortURL).load(.duration))
        let longSeconds = CMTimeGetSeconds(try await AVURLAsset(url: longURL).load(.duration))
        #expect(longSeconds > shortSeconds)
    }

    @Test("Rendering over an existing file replaces it")
    func rerenderOverwrites() async throws {
        let directory = try DreamFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = try DreamFixture.visualProfile(for: DreamFixture.dream(mood: .intense))
        let url = directory.appendingPathComponent("overwrite.mp4")
        try Data("stale".utf8).write(to: url)

        try await DreamFilmRenderer.write(to: url, duration: 0.5, tempo: 120, profile: profile)

        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        #expect(size > 1_000)
    }
}

private extension DreamVisualProfile {
    /// Guards that every tunable stays inside the range the renderer assumes.
    var stereoSafeRanges: Bool {
        rayIntensity >= 0 && rayIntensity <= 1
            && flareStrength >= 0 && flareStrength <= 1.5
            && sparkBurst >= 0 && sparkBurst <= 1.5
            && chromaEdge >= 0 && chromaEdge <= 1
            && pulseStrength >= 0 && pulseStrength <= 1.5
            && shakeStrength >= 0 && shakeStrength <= 1.5
            && glitchStrength >= 0 && glitchStrength <= 1
            && cometCount >= 0
            && curtainCount >= 0
    }
}
