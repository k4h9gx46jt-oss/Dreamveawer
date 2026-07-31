import AVFoundation
import CoreGraphics
import SwiftUI
import UIKit

/// Visual direction for a dream film. Mirrors the musical genre so picture and score agree.
struct DreamVisualProfile {
    enum Style: String {
        case auroraCathedral
        case pastoralDrift
        case stellarNebula
        case stormHorizon
        case emberTempest
        case fracture
    }

    let style: Style
    /// Five-stop cinematic ramp: shadow, primary, secondary, highlight, spark.
    let palette: [UIColor]
    let ribbonCount: Int
    let ribbonAmplitude: Double
    let ribbonWidth: Double
    let flowSpeed: Double
    let nebulaLayers: Int
    let nebulaScale: Double
    let starCount: Int
    let particleCount: Int
    let particleSpeed: Double
    let particleSize: Double
    let bokehCount: Int
    let rayCount: Int
    let rayIntensity: Double
    let curtainCount: Int
    let cometCount: Int
    let flareStrength: Double
    let sparkBurst: Double
    let chromaEdge: Double
    let pulseStrength: Double
    let shakeStrength: Double
    let glitchStrength: Double
    let grainAmount: Double
    let vignette: Double
    let horizonPhase: Double
    let warmth: Double
    let seed: UInt64

    var diagnostics: [String: String] {
        [
            "visualStyle": style.rawValue,
            "ribbons": "\(ribbonCount)",
            "particles": "\(particleCount)",
            "resolution": "\(DreamFilmRenderer.width)x\(DreamFilmRenderer.height)"
        ]
    }

    init(mood: DreamMood, genre: DreamGenre, profile: REMDreamProfile, seed: UInt64) {
        let intensity = min(max(profile.intensityScore, 0), 1)
        let polarity = Double(profile.moodPolarity)
        let apnea = Double(profile.apneaSpikeCount)
        let noise = Double(profile.noiseSpikeCount)
        self.seed = seed
        var random = DreamRandom(seed: seed &* 31 &+ 17)

        switch genre {
        case .symphonic: style = .auroraCathedral
        case .chamber: style = .pastoralDrift
        case .celestial: style = .stellarNebula
        case .cinematic: style = .stormHorizon
        case .hardRock: style = .emberTempest
        case .industrial: style = .fracture
        }

        palette = Self.makePalette(mood: mood, style: style, polarity: polarity)
        horizonPhase = Double(random.nextFloat()) * 6.2831
        let variation = Double(random.nextFloat())

        switch style {
        case .auroraCathedral:
            ribbonCount = 5 + Int(intensity * 3)
            ribbonAmplitude = 0.10 + intensity * 0.07
            ribbonWidth = 1.6
            flowSpeed = 0.22 + intensity * 0.14
            nebulaLayers = 4
            nebulaScale = 1.15
            starCount = 90
            particleCount = 110
            particleSpeed = 0.5
            particleSize = 2.6
            bokehCount = 16
            rayCount = 11
            rayIntensity = 0.10
            curtainCount = 5
            cometCount = 2
            flareStrength = 0.55
            sparkBurst = 0.35
            chromaEdge = 0.25
            pulseStrength = 0.45
            shakeStrength = 0.05
            glitchStrength = 0
            warmth = 0.9
            vignette = 0.5
        case .pastoralDrift:
            ribbonCount = 4
            ribbonAmplitude = 0.08
            ribbonWidth = 1.3
            flowSpeed = 0.16
            nebulaLayers = 3
            nebulaScale = 1.3
            starCount = 40
            particleCount = 80
            particleSpeed = 0.35
            particleSize = 3.2
            bokehCount = 22
            rayCount = 8
            rayIntensity = 0.09
            curtainCount = 3
            cometCount = 1
            flareStrength = 0.40
            sparkBurst = 0.20
            chromaEdge = 0.15
            pulseStrength = 0.3
            shakeStrength = 0.02
            glitchStrength = 0
            warmth = 1.0
            vignette = 0.42
        case .stellarNebula:
            ribbonCount = 3
            ribbonAmplitude = 0.13
            ribbonWidth = 1.1
            flowSpeed = 0.12
            nebulaLayers = 5
            nebulaScale = 1.35
            starCount = 260
            particleCount = 130
            particleSpeed = 0.3
            particleSize = 2.0
            bokehCount = 12
            rayCount = 9
            rayIntensity = 0.12
            curtainCount = 4
            cometCount = 5
            flareStrength = 0.70
            sparkBurst = 0.45
            chromaEdge = 0.30
            pulseStrength = 0.5
            shakeStrength = 0.03
            glitchStrength = 0
            warmth = 0.6
            vignette = 0.6
        case .stormHorizon:
            ribbonCount = 6 + Int(intensity * 3)
            ribbonAmplitude = 0.16 + intensity * 0.08
            ribbonWidth = 1.9
            flowSpeed = 0.42 + intensity * 0.2
            nebulaLayers = 4
            nebulaScale = 1.2
            starCount = 70
            particleCount = 190
            particleSpeed = 1.0
            particleSize = 2.4
            bokehCount = 10
            rayCount = 13
            rayIntensity = 0.16
            curtainCount = 2
            cometCount = 3
            flareStrength = 0.85
            sparkBurst = 0.75
            chromaEdge = 0.45
            pulseStrength = 0.85
            shakeStrength = 0.35
            glitchStrength = 0.08
            warmth = 0.75
            vignette = 0.66
        case .emberTempest:
            ribbonCount = 8 + Int(intensity * 4)
            ribbonAmplitude = 0.20 + intensity * 0.10
            ribbonWidth = 2.2
            flowSpeed = 0.85 + intensity * 0.45
            nebulaLayers = 3
            nebulaScale = 1.0
            starCount = 50
            particleCount = 300
            particleSpeed = 1.9
            particleSize = 2.2
            bokehCount = 8
            rayCount = 15
            rayIntensity = 0.2
            curtainCount = 0
            cometCount = 4
            flareStrength = 1.0
            sparkBurst = 1.0
            chromaEdge = 0.60
            pulseStrength = 1.0
            shakeStrength = 0.8
            glitchStrength = 0.35
            warmth = 1.15
            vignette = 0.74
        case .fracture:
            ribbonCount = 9 + Int(intensity * 4)
            ribbonAmplitude = 0.24 + intensity * 0.12
            ribbonWidth = 1.7
            flowSpeed = 1.15 + intensity * 0.6
            nebulaLayers = 3
            nebulaScale = 0.9
            starCount = 60
            particleCount = 340
            particleSpeed = 2.4
            particleSize = 1.9
            bokehCount = 6
            rayCount = 17
            rayIntensity = 0.18
            curtainCount = 0
            cometCount = 3
            flareStrength = 0.80
            sparkBurst = 0.90
            chromaEdge = 0.90
            pulseStrength = 1.0
            shakeStrength = 1.0
            glitchStrength = 0.85
            warmth = 0.7
            vignette = 0.8
        }

        // Apnea roughens the grain, ambient noise adds seed-driven texture variance.
        grainAmount = min(0.3, 0.09 + apnea * 0.012 + noise * 0.004 + variation * 0.03)
    }

    private static func makePalette(mood: DreamMood, style: Style, polarity: Double) -> [UIColor] {
        let base = mood.colors.map { UIColor($0) }
        let primary = base.first ?? UIColor.systemPurple
        let secondary = base.count > 1 ? base[1] : primary.shifted(hue: 0.09)

        let shadow: UIColor
        let highlight: UIColor
        let spark: UIColor
        switch style {
        case .auroraCathedral:
            shadow = primary.shifted(hue: -0.05, saturation: 1.25, brightness: 0.18)
            highlight = secondary.shifted(hue: 0.04, saturation: 0.6, brightness: 1.55)
            spark = UIColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1)
        case .pastoralDrift:
            shadow = primary.shifted(hue: 0.02, saturation: 0.9, brightness: 0.24)
            highlight = secondary.shifted(hue: -0.03, saturation: 0.5, brightness: 1.6)
            spark = UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1)
        case .stellarNebula:
            shadow = primary.shifted(hue: -0.02, saturation: 1.3, brightness: 0.12)
            highlight = secondary.shifted(hue: 0.06, saturation: 0.7, brightness: 1.7)
            spark = UIColor(red: 0.88, green: 0.94, blue: 1.0, alpha: 1)
        case .stormHorizon:
            shadow = primary.shifted(hue: -0.03, saturation: 1.2, brightness: 0.14)
            highlight = secondary.shifted(hue: 0.02, saturation: 0.85, brightness: 1.45)
            spark = UIColor(red: 1.0, green: 0.90, blue: 0.72, alpha: 1)
        case .emberTempest:
            shadow = primary.shifted(hue: -0.02, saturation: 1.35, brightness: 0.10)
            highlight = secondary.shifted(hue: -0.02, saturation: 1.0, brightness: 1.5)
            spark = UIColor(red: 1.0, green: 0.82, blue: 0.55, alpha: 1)
        case .fracture:
            shadow = primary.shifted(hue: 0.03, saturation: 1.4, brightness: 0.08)
            highlight = secondary.shifted(hue: polarity < 0 ? -0.08 : 0.08, saturation: 1.1, brightness: 1.4)
            spark = UIColor(red: 0.95, green: 1.0, blue: 0.98, alpha: 1)
        }
        return [shadow, primary, secondary, highlight, spark]
    }
}

enum DreamFilmRenderer {
    static let width = 1280
    static let height = 720
    static let fps: Double = 30

    static func write(to url: URL,
                      duration: TimeInterval,
                      tempo: Double,
                      profile: DreamVisualProfile,
                      progressHandler: (@Sendable (Double) -> Void)? = nil) async throws {
        try? FileManager.default.removeItem(at: url)

        let assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 9_000_000,
                AVVideoMaxKeyFrameIntervalKey: Int(fps * 2),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        writerInput.expectsMediaDataInRealTime = false
        guard assetWriter.canAdd(writerInput) else {
            throw DreamMediaComposer.ComposerError.videoGenerationFailed
        }
        assetWriter.add(writerInput)

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput,
                                                           sourcePixelBufferAttributes: attributes)

        guard assetWriter.startWriting() else {
            throw DreamMediaComposer.ComposerError.videoGenerationFailed
        }
        assetWriter.startSession(atSourceTime: .zero)

        let size = CGSize(width: width, height: height)
        let scene = DreamFilmScene(profile: profile, size: size)
        let totalFrames = max(1, Int(duration * fps))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        var energy = 0.3

        for frameIndex in 0..<totalFrames {
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 4_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else { break }
            var pixelBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
                  let frameBuffer = pixelBuffer else {
                continue
            }

            CVPixelBufferLockBaseAddress(frameBuffer, [])
            if let context = CGContext(data: CVPixelBufferGetBaseAddress(frameBuffer),
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: CVPixelBufferGetBytesPerRow(frameBuffer),
                                       space: colorSpace,
                                       bitmapInfo: bitmapInfo) {
                context.setShouldAntialias(true)
                context.interpolationQuality = .high

                let time = Double(frameIndex) / fps
                let position = time / max(duration, 0.001)
                energy += (sectionEnergy(position) - energy) * 0.05
                scene.render(into: context,
                             time: time,
                             energy: energy,
                             tempo: tempo,
                             frameIndex: frameIndex,
                             fade: edgeFade(time: time, duration: duration))
            }
            CVPixelBufferUnlockBaseAddress(frameBuffer, [])

            adaptor.append(frameBuffer,
                           withPresentationTime: CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps)))

            if frameIndex % 15 == 0 {
                progressHandler?(0.3 + 0.65 * Double(frameIndex) / Double(totalFrames))
            }
        }

        writerInput.markAsFinished()
        await assetWriter.finishWriting()
    }

    /// Mirrors the arrangement of the generated score so the picture builds with the music.
    private static func sectionEnergy(_ position: Double) -> Double {
        switch position {
        case ..<0.10: return 0.30
        case ..<0.28: return 0.58
        case ..<0.50: return 1.00
        case ..<0.64: return 0.52
        case ..<0.88: return 1.00
        default: return 0.35
        }
    }

    private static func edgeFade(time: Double, duration: TimeInterval) -> Double {
        min(1, time / 1.2) * min(1, max(0, (duration - time) / 1.8))
    }
}

private struct FilmStar {
    let x: Double
    let y: Double
    let radius: Double
    let twinkleSpeed: Double
    let phase: Double
    let depth: Double
    let colorIndex: Int
}

private struct FilmParticle {
    let originX: Double
    let originY: Double
    let velocityX: Double
    let velocityY: Double
    let size: Double
    let lifeOffset: Double
    let wobble: Double
    let colorIndex: Int
}

private struct FilmBokeh {
    let x: Double
    let y: Double
    let radius: Double
    let drift: Double
    let alpha: Double
    let colorIndex: Int
}

private struct FilmComet {
    let startX: Double
    let startY: Double
    let angle: Double
    let speed: Double
    let period: Double
    let offset: Double
    let length: Double
    let thickness: Double
    let colorIndex: Int
}

private final class DreamFilmScene {
    private let profile: DreamVisualProfile
    private let size: CGSize
    private let colors: [UIColor]
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let stars: [FilmStar]
    private let particles: [FilmParticle]
    private let bokeh: [FilmBokeh]
    private let comets: [FilmComet]
    private let grain: CGImage?

    init(profile: DreamVisualProfile, size: CGSize) {
        self.profile = profile
        self.size = size
        var ramp = profile.palette.isEmpty ? [UIColor.black, .systemPurple, .systemPink, .white] : profile.palette
        while ramp.count < 5 { ramp.append(ramp[ramp.count - 1]) }
        self.colors = ramp
        let paletteCount = ramp.count
        var random = DreamRandom(seed: profile.seed)

        stars = (0..<profile.starCount).map { _ in
            FilmStar(x: Double(random.nextFloat()) * Double(size.width),
                     y: Double(random.nextFloat()) * Double(size.height),
                     radius: 0.7 + Double(random.nextFloat()) * 2.1,
                     twinkleSpeed: 0.5 + Double(random.nextFloat()) * 3.6,
                     phase: Double(random.nextFloat()) * 6.2831,
                     depth: 0.2 + Double(random.nextFloat()) * 0.8,
                     colorIndex: 2 + Int(random.nextFloat() * 3) % 3)
        }

        particles = (0..<profile.particleCount).map { _ in
            let angle = Double(random.nextFloat()) * 6.2831
            let speed = 0.25 + Double(random.nextFloat()) * 0.95
            return FilmParticle(originX: Double(random.nextFloat()) * Double(size.width),
                                originY: Double(random.nextFloat()) * Double(size.height),
                                velocityX: cos(angle) * speed,
                                velocityY: sin(angle) * speed * 0.7 - 0.35,
                                size: profile.particleSize * (0.4 + Double(random.nextFloat()) * 1.3),
                                lifeOffset: Double(random.nextFloat()),
                                wobble: Double(random.nextFloat()) * 1.4,
                                colorIndex: 1 + Int(random.nextFloat() * Float(paletteCount - 1)) % max(1, paletteCount - 1))
        }

        bokeh = (0..<profile.bokehCount).map { _ in
            FilmBokeh(x: Double(random.nextFloat()) * Double(size.width),
                      y: Double(random.nextFloat()) * Double(size.height),
                      radius: Double(size.width) * (0.025 + Double(random.nextFloat()) * 0.075),
                      drift: 0.06 + Double(random.nextFloat()) * 0.22,
                      alpha: 0.10 + Double(random.nextFloat()) * 0.22,
                      colorIndex: 2 + Int(random.nextFloat() * 3) % 3)
        }

        comets = (0..<profile.cometCount).map { _ in
            let downward = Double(random.nextFloat()) * 0.9 + 2.6
            return FilmComet(startX: Double(random.nextFloat()) * Double(size.width) * 1.3 - Double(size.width) * 0.15,
                             startY: Double(random.nextFloat()) * Double(size.height) * 0.5,
                             angle: downward,
                             speed: 0.55 + Double(random.nextFloat()) * 0.85,
                             period: 6 + Double(random.nextFloat()) * 9,
                             offset: Double(random.nextFloat()) * 12,
                             length: 90 + Double(random.nextFloat()) * 190,
                             thickness: 1.4 + Double(random.nextFloat()) * 2.4,
                             colorIndex: 3 + Int(random.nextFloat() * 2) % 2)
        }

        grain = DreamFilmScene.makeGrainTile(edge: 192, seed: profile.seed &+ 991)
    }

    func render(into context: CGContext,
                time: Double,
                energy: Double,
                tempo: Double,
                frameIndex: Int,
                fade: Double) {
        let beat = time * tempo / 60
        let beatPhase = beat - floor(beat)
        let pulse = pow(max(0, 1 - beatPhase), 4) * energy

        context.setBlendMode(.normal)
        context.setAlpha(1)
        context.setFillColor(colors[0].cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        context.saveGState()
        applyCamera(context, time: time, pulse: pulse)
        drawBackdrop(context, time: time)
        drawNebula(context, time: time, energy: energy)
        drawCurtains(context, time: time, energy: energy)
        drawKeyLight(context, time: time, energy: energy, pulse: pulse)
        drawRibbons(context, time: time, energy: energy, pulse: pulse)
        drawStars(context, time: time, energy: energy)
        drawComets(context, time: time, energy: energy)
        drawRays(context, time: time, energy: energy, pulse: pulse)
        drawParticles(context, time: time, energy: energy)
        drawBokeh(context, time: time, energy: energy)
        drawLensFlare(context, time: time, energy: energy, pulse: pulse)
        drawBeatBloom(context, pulse: pulse, energy: energy)
        drawBeatSparks(context, beat: beat, energy: energy)
        drawGlitch(context, beat: beat, energy: energy, frameIndex: frameIndex)
        context.restoreGState()

        applyColorGrade(context, time: time)
        applyEdgeChroma(context)
        applyVignette(context)
        applyGrain(context, frameIndex: frameIndex)

        if fade < 0.999 {
            context.saveGState()
            context.setBlendMode(.normal)
            context.setFillColor(UIColor.black.withAlphaComponent(CGFloat(1 - fade)).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.restoreGState()
        }
    }
}

private extension DreamFilmScene {
    /// Layered sine sum — organic drift without the cost of real value noise.
    func flow(_ x: Double, seed: Double) -> Double {
        sin(x + seed) * 0.55 + sin(x * 2.17 + seed * 1.7) * 0.28 + sin(x * 4.31 + seed * 2.9) * 0.17
    }

    func keyLightPosition(time: Double) -> CGPoint {
        CGPoint(x: size.width * CGFloat(0.5 + 0.22 * sin(time * 0.08 + profile.horizonPhase)),
                y: size.height * CGFloat(0.30 + 0.09 * cos(time * 0.06 + profile.horizonPhase)))
    }

    func gradient(_ stops: [UIColor], locations: [CGFloat]) -> CGGradient? {
        CGGradient(colorsSpace: colorSpace, colors: stops.map(\.cgColor) as CFArray, locations: locations)
    }

    func applyCamera(_ context: CGContext, time: Double, pulse: Double) {
        let zoom = 1.06 + 0.025 * sin(time * 0.17) + pulse * profile.pulseStrength * 0.035
        let driftX = sin(time * 0.11) * Double(size.width) * 0.012
        let driftY = cos(time * 0.09) * Double(size.height) * 0.012
        let shake = pulse * profile.shakeStrength
        let shakeX = sin(time * 61) * shake * Double(size.width) * 0.005
        let shakeY = cos(time * 47) * shake * Double(size.height) * 0.005
        context.translateBy(x: size.width / 2 + CGFloat(driftX + shakeX),
                            y: size.height / 2 + CGFloat(driftY + shakeY))
        context.scaleBy(x: CGFloat(zoom), y: CGFloat(zoom))
        context.rotate(by: CGFloat(sin(time * 0.05) * 0.014))
        context.translateBy(x: -size.width / 2, y: -size.height / 2)
    }

    func drawBackdrop(_ context: CGContext, time: Double) {
        let midpoint = CGFloat(0.38 + sin(time * 0.13) * 0.07)
        guard let ramp = gradient([colors[0], colors[1], colors[2], colors[0].shifted(brightness: 0.55)],
                                  locations: [0, midpoint, 0.74, 1]) else { return }
        let tilt = CGFloat(sin(time * 0.06) * 0.28)
        context.drawLinearGradient(ramp,
                                   start: CGPoint(x: size.width * (0.5 - tilt), y: 0),
                                   end: CGPoint(x: size.width * (0.5 + tilt), y: size.height),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    func drawNebula(_ context: CGContext, time: Double, energy: Double) {
        guard profile.nebulaLayers > 0 else { return }
        context.saveGState()
        context.setBlendMode(.screen)
        for layer in 0..<profile.nebulaLayers {
            let normalized = Double(layer) / Double(profile.nebulaLayers)
            let speed = 0.05 + normalized * 0.1
            let center = CGPoint(x: size.width * CGFloat(0.5 + 0.33 * sin(time * speed + normalized * 5.1)),
                                 y: size.height * CGFloat(0.46 + 0.29 * cos(time * speed * 0.8 + normalized * 3.7)))
            let radius = Double(size.width) * (0.22 + normalized * 0.28) * profile.nebulaScale
                * (0.9 + 0.12 * sin(time * 0.4 + normalized * 2))
            let tint = colors[(layer + 1) % colors.count].withAlphaComponent(CGFloat(0.14 + 0.18 * energy))
            guard let cloud = gradient([tint, tint.withAlphaComponent(0)], locations: [0, 1]) else { continue }
            context.drawRadialGradient(cloud,
                                       startCenter: center,
                                       startRadius: 0,
                                       endCenter: center,
                                       endRadius: CGFloat(radius),
                                       options: [])
        }
        context.restoreGState()
    }

    /// Vertical shimmering light curtains, the signature of the calmer aurora styles.
    func drawCurtains(_ context: CGContext, time: Double, energy: Double) {
        guard profile.curtainCount > 0 else { return }
        context.saveGState()
        context.setBlendMode(.plusLighter)
        for index in 0..<profile.curtainCount {
            let normalized = Double(index) / Double(profile.curtainCount)
            let centerX = size.width * CGFloat(0.5 + 0.44 * sin(time * (0.07 + normalized * 0.05)
                + normalized * 6.2831 + profile.horizonPhase))
            let top = size.height * CGFloat(0.02 + 0.08 * normalized)
            let height = size.height * CGFloat(0.55 + 0.35 * abs(cos(time * 0.19 + normalized * 2)))
            let tint = colors[2 + index % 2]
            let shimmer = 0.45 + 0.55 * abs(sin(time * 0.5 + normalized * 4))
            // Three nested bands fake a soft horizontal falloff without a second gradient pass.
            for band in 0..<3 {
                let width = size.width * CGFloat((0.075 - Double(band) * 0.022)
                    * (1 + 0.35 * sin(time * 0.23 + normalized * 3)))
                guard width > 0.5 else { continue }
                let alpha = CGFloat((0.05 + Double(band) * 0.035) * shimmer * (0.4 + 0.6 * energy))
                guard let ramp = gradient([tint.withAlphaComponent(0),
                                           tint.withAlphaComponent(alpha),
                                           tint.withAlphaComponent(0)],
                                          locations: [0, 0.4, 1]) else { continue }
                context.saveGState()
                context.clip(to: CGRect(x: centerX - width / 2, y: top, width: width, height: height))
                context.drawLinearGradient(ramp,
                                           start: CGPoint(x: centerX, y: top),
                                           end: CGPoint(x: centerX, y: top + height),
                                           options: [])
                context.restoreGState()
            }
        }
        context.restoreGState()
    }

    /// Streaking comets that sweep the frame on their own slow cycles.
    func drawComets(_ context: CGContext, time: Double, energy: Double) {
        guard !comets.isEmpty else { return }
        context.saveGState()
        context.setBlendMode(.plusLighter)
        context.setLineCap(.round)
        let travel = Double(max(size.width, size.height)) * 1.4
        for comet in comets {
            let cycle = (time + comet.offset).truncatingRemainder(dividingBy: comet.period) / comet.period
            guard cycle < 0.32 else { continue }
            let progress = cycle / 0.32
            let fade = sin(progress * .pi) * (0.4 + 0.6 * energy)
            guard fade > 0.02 else { continue }
            let dx = cos(comet.angle)
            let dy = sin(comet.angle)
            let headX = comet.startX + dx * progress * travel * comet.speed
            let headY = comet.startY + dy * progress * travel * comet.speed
            let tint = colors[comet.colorIndex % colors.count]
            for segment in 0..<6 {
                let near = Double(segment) / 6
                let far = Double(segment + 1) / 6
                let alpha = fade * (1 - near) * 0.4
                context.setStrokeColor(tint.withAlphaComponent(CGFloat(alpha)).cgColor)
                context.setLineWidth(CGFloat(comet.thickness * (1 - near)))
                context.move(to: CGPoint(x: headX - dx * comet.length * near, y: headY - dy * comet.length * near))
                context.addLine(to: CGPoint(x: headX - dx * comet.length * far, y: headY - dy * comet.length * far))
                context.strokePath()
            }
            let head = CGFloat(comet.thickness * 1.6)
            context.setFillColor(colors[4].withAlphaComponent(CGFloat(fade * 0.85)).cgColor)
            context.fillEllipse(in: CGRect(x: CGFloat(headX) - head, y: CGFloat(headY) - head,
                                           width: head * 2, height: head * 2))
        }
        context.restoreGState()
    }

    /// Anamorphic streak plus ghosting along the lens axis.
    func drawLensFlare(_ context: CGContext, time: Double, energy: Double, pulse: Double) {
        guard profile.flareStrength > 0.01 else { return }
        let origin = keyLightPosition(time: time)
        let strength = profile.flareStrength * (0.45 + 0.55 * energy) * (1 + pulse * 0.8)
        context.saveGState()
        context.setBlendMode(.plusLighter)

        let streakWidth = size.width * CGFloat(0.85 + 0.35 * pulse)
        let streakHeight = CGFloat(3 + 7 * strength)
        let streak = colors[4].withAlphaComponent(CGFloat(min(0.55, strength * 0.42)))
        if let ramp = gradient([streak.withAlphaComponent(0), streak, streak.withAlphaComponent(0)],
                               locations: [0, 0.5, 1]) {
            context.saveGState()
            context.clip(to: CGRect(x: origin.x - streakWidth / 2,
                                    y: origin.y - streakHeight / 2,
                                    width: streakWidth,
                                    height: streakHeight))
            context.drawLinearGradient(ramp,
                                       start: CGPoint(x: origin.x - streakWidth / 2, y: origin.y),
                                       end: CGPoint(x: origin.x + streakWidth / 2, y: origin.y),
                                       options: [])
            context.restoreGState()
        }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for index in 1...5 {
            let travel = CGFloat(index) * 0.62
            let ghostCenter = CGPoint(x: origin.x + (center.x - origin.x) * travel,
                                      y: origin.y + (center.y - origin.y) * travel)
            let radius = CGFloat(7 + Double(index) * 10) * CGFloat(1 + strength * 0.6)
            let tint = colors[(index + 1) % colors.count]
                .withAlphaComponent(CGFloat(strength * 0.11 / Double(index)))
            guard let ghost = gradient([tint.withAlphaComponent(0), tint, tint.withAlphaComponent(0)],
                                       locations: [0.35, 0.75, 1]) else { continue }
            context.drawRadialGradient(ghost,
                                       startCenter: ghostCenter,
                                       startRadius: 0,
                                       endCenter: ghostCenter,
                                       endRadius: radius,
                                       options: [])
        }
        context.restoreGState()
    }

    /// Radial spark spray fired on every bar downbeat.
    func drawBeatSparks(_ context: CGContext, beat: Double, energy: Double) {
        guard profile.sparkBurst > 0.01 else { return }
        let bar = beat / 4
        let phase = bar - floor(bar)
        guard phase < 0.45 else { return }
        let progress = phase / 0.45
        var random = DreamRandom(seed: profile.seed &+ UInt64(bitPattern: Int64(Int(bar) &* 104_729 &+ 7)))
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let count = 12 + Int(profile.sparkBurst * 28)
        let reach = Double(size.width) * 0.42
        context.saveGState()
        context.setBlendMode(.plusLighter)
        context.setLineCap(.round)
        for _ in 0..<count {
            let angle = Double(random.nextFloat()) * 6.2831
            let speed = 0.35 + Double(random.nextFloat())
            let distance = progress * speed * reach
            let alpha = (1 - progress) * profile.sparkBurst * (0.4 + 0.6 * energy) * 0.7
            guard alpha > 0.02 else { continue }
            let x = origin.x + CGFloat(cos(angle) * distance)
            let y = origin.y + CGFloat(sin(angle) * distance * 0.72)
            let tailX = origin.x + CGFloat(cos(angle) * distance * 0.86)
            let tailY = origin.y + CGFloat(sin(angle) * distance * 0.72 * 0.86)
            let tint = colors[3 + Int(random.nextFloat() * 2) % 2]
            context.setStrokeColor(tint.withAlphaComponent(CGFloat(alpha)).cgColor)
            context.setLineWidth(CGFloat(1 + profile.sparkBurst * 2))
            context.move(to: CGPoint(x: tailX, y: tailY))
            context.addLine(to: CGPoint(x: x, y: y))
            context.strokePath()
        }
        context.restoreGState()
    }

    func drawKeyLight(_ context: CGContext, time: Double, energy: Double, pulse: Double) {
        let center = keyLightPosition(time: time)
        let radius = Double(size.width) * (0.17 + 0.05 * sin(time * 0.3)) * (1 + pulse * 0.3)
        let core = colors[3].withAlphaComponent(CGFloat(0.30 + 0.28 * energy))
        guard let halo = gradient([core, core.withAlphaComponent(0)], locations: [0, 1]) else { return }
        context.saveGState()
        context.setBlendMode(.plusLighter)
        context.drawRadialGradient(halo,
                                   startCenter: center,
                                   startRadius: 0,
                                   endCenter: center,
                                   endRadius: CGFloat(radius * 2.6),
                                   options: [])
        context.restoreGState()
    }

    func drawRibbons(_ context: CGContext, time: Double, energy: Double, pulse: Double) {
        guard profile.ribbonCount > 0 else { return }
        context.saveGState()
        context.setBlendMode(.plusLighter)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let steps = 96
        for index in 0..<profile.ribbonCount {
            let normalized = Double(index) / Double(profile.ribbonCount)
            let seedPhase = normalized * 6.2831 + Double(index) * 1.37 + profile.horizonPhase
            let path = CGMutablePath()
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let wave = flow(progress * (2.2 + normalized * 2.4) + time * profile.flowSpeed, seed: seedPhase)
                let band = 0.5 + (normalized - 0.5) * 0.62
                let y = (band + wave * profile.ribbonAmplitude * (0.65 + 0.5 * energy)) * Double(size.height)
                let point = CGPoint(x: CGFloat(progress) * size.width, y: CGFloat(y))
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            let tint = colors[1 + index % max(1, colors.count - 1)]
            let baseWidth = profile.ribbonWidth * (0.7 + normalized * 0.9) * (1 + pulse * 0.6)
            for pass in 0..<3 {
                context.setStrokeColor(tint.withAlphaComponent(CGFloat((0.045 + Double(pass) * 0.075) * (0.45 + 0.55 * energy))).cgColor)
                context.setLineWidth(CGFloat(baseWidth * Double(3 - pass) * 2.8))
                context.addPath(path)
                context.strokePath()
            }
        }
        context.restoreGState()
    }

    func drawStars(_ context: CGContext, time: Double, energy: Double) {
        guard !stars.isEmpty else { return }
        context.saveGState()
        context.setBlendMode(.plusLighter)
        for star in stars {
            let twinkle = 0.45 + 0.55 * sin(time * star.twinkleSpeed + star.phase)
            let alpha = star.depth * twinkle * (0.35 + 0.65 * energy)
            guard alpha > 0.02 else { continue }
            let radius = CGFloat(star.radius * (0.8 + 0.4 * twinkle))
            let drift = CGFloat(sin(time * 0.05 + star.phase) * 7 * star.depth)
            context.setFillColor(colors[star.colorIndex % colors.count].withAlphaComponent(CGFloat(alpha)).cgColor)
            context.fillEllipse(in: CGRect(x: CGFloat(star.x) + drift - radius,
                                           y: CGFloat(star.y) - radius,
                                           width: radius * 2,
                                           height: radius * 2))
        }
        context.restoreGState()
    }

    func drawRays(_ context: CGContext, time: Double, energy: Double, pulse: Double) {
        guard profile.rayCount > 0, profile.rayIntensity > 0.001 else { return }
        let origin = keyLightPosition(time: time)
        let reach = Double(max(size.width, size.height)) * 1.6
        context.saveGState()
        context.setBlendMode(.plusLighter)
        for index in 0..<profile.rayCount {
            let normalized = Double(index) / Double(profile.rayCount)
            let angle = normalized * 6.2831 + time * 0.05 + sin(time * 0.2 + normalized * 4) * 0.12
            let spread = (0.010 + 0.020 * abs(sin(time * 0.3 + normalized * 7))) * (1 + pulse * 0.6)
            let wedge = CGMutablePath()
            wedge.move(to: origin)
            wedge.addLine(to: CGPoint(x: origin.x + CGFloat(cos(angle - spread) * reach),
                                      y: origin.y + CGFloat(sin(angle - spread) * reach)))
            wedge.addLine(to: CGPoint(x: origin.x + CGFloat(cos(angle + spread) * reach),
                                      y: origin.y + CGFloat(sin(angle + spread) * reach)))
            wedge.closeSubpath()

            let alpha = profile.rayIntensity * (0.25 + 0.75 * energy)
                * (0.35 + 0.65 * abs(sin(time * 0.4 + normalized * 5)))
            let tint = colors[3].withAlphaComponent(CGFloat(alpha))
            guard let beam = gradient([tint, tint.withAlphaComponent(0)], locations: [0, 1]) else { continue }
            context.saveGState()
            context.addPath(wedge)
            context.clip()
            context.drawRadialGradient(beam,
                                       startCenter: origin,
                                       startRadius: 0,
                                       endCenter: origin,
                                       endRadius: CGFloat(reach),
                                       options: [])
            context.restoreGState()
        }
        context.restoreGState()
    }

    func drawParticles(_ context: CGContext, time: Double, energy: Double) {
        guard !particles.isEmpty else { return }
        context.saveGState()
        context.setBlendMode(.plusLighter)
        context.setLineCap(.round)
        let lifespan = 4.6
        let travel = Double(size.width) * 0.06
        for particle in particles {
            let age = fmod(time * profile.particleSpeed + particle.lifeOffset * lifespan, lifespan)
            let alpha = sin(age / lifespan * .pi) * (0.3 + 0.7 * energy)
            guard alpha > 0.02 else { continue }
            let wobble = sin(time * 1.7 + particle.wobble * 6) * particle.wobble * 14
            let previous = max(0, age - 0.1)
            let tint = colors[particle.colorIndex % colors.count]
            let x = particle.originX + particle.velocityX * age * travel + wobble
            let y = particle.originY + particle.velocityY * age * travel
            let px = particle.originX + particle.velocityX * previous * travel + wobble
            let py = particle.originY + particle.velocityY * previous * travel

            context.setStrokeColor(tint.withAlphaComponent(CGFloat(alpha * 0.5)).cgColor)
            context.setLineWidth(CGFloat(particle.size * 0.85))
            context.move(to: CGPoint(x: px, y: py))
            context.addLine(to: CGPoint(x: x, y: y))
            context.strokePath()

            let radius = CGFloat(particle.size * 0.6)
            context.setFillColor(tint.withAlphaComponent(CGFloat(alpha)).cgColor)
            context.fillEllipse(in: CGRect(x: CGFloat(x) - radius, y: CGFloat(y) - radius,
                                           width: radius * 2, height: radius * 2))
        }
        context.restoreGState()
    }

    func drawBokeh(_ context: CGContext, time: Double, energy: Double) {
        guard !bokeh.isEmpty else { return }
        context.saveGState()
        context.setBlendMode(.screen)
        for disc in bokeh {
            let center = CGPoint(x: CGFloat(disc.x + sin(time * disc.drift + disc.alpha * 20) * Double(size.width) * 0.05),
                                 y: CGFloat(disc.y + cos(time * disc.drift * 0.8 + disc.alpha * 14) * Double(size.height) * 0.04))
            let radius = CGFloat(disc.radius * (0.85 + 0.15 * sin(time * 0.6 + disc.alpha * 25)))
            let peak = CGFloat(disc.alpha * (0.3 + 0.7 * energy))
            let tint = colors[disc.colorIndex % colors.count]
            guard let disc0 = gradient([tint.withAlphaComponent(peak * 0.35),
                                        tint.withAlphaComponent(peak),
                                        tint.withAlphaComponent(0)],
                                       locations: [0, 0.8, 1]) else { continue }
            context.drawRadialGradient(disc0,
                                       startCenter: center,
                                       startRadius: 0,
                                       endCenter: center,
                                       endRadius: radius,
                                       options: [])
        }
        context.restoreGState()
    }

    func drawBeatBloom(_ context: CGContext, pulse: Double, energy: Double) {
        guard pulse > 0.015, profile.pulseStrength > 0.01 else { return }
        let strength = pulse * profile.pulseStrength * (0.35 + 0.65 * energy)
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        context.saveGState()
        context.setBlendMode(.plusLighter)

        let tint = colors[4 % colors.count].withAlphaComponent(CGFloat(strength * 0.30))
        if let bloom = gradient([tint, tint.withAlphaComponent(0)], locations: [0, 1]) {
            context.drawRadialGradient(bloom,
                                       startCenter: center,
                                       startRadius: 0,
                                       endCenter: center,
                                       endRadius: size.width * CGFloat(0.32 + 0.45 * pulse),
                                       options: [])
        }

        let ring = CGFloat(Double(size.width) * (0.1 + (1 - pulse) * 0.5))
        context.setStrokeColor(colors[3].withAlphaComponent(CGFloat(strength * 0.24)).cgColor)
        context.setLineWidth(CGFloat(2 + strength * 7))
        context.strokeEllipse(in: CGRect(x: center.x - ring,
                                         y: center.y - ring * 0.62,
                                         width: ring * 2,
                                         height: ring * 1.24))
        context.restoreGState()
    }

    func drawGlitch(_ context: CGContext, beat: Double, energy: Double, frameIndex: Int) {
        guard profile.glitchStrength > 0.01 else { return }
        let burst = max(0, 1 - (beat - floor(beat)) * 5)
        guard burst > 0.05 else { return }
        var random = DreamRandom(seed: profile.seed &+ UInt64(bitPattern: Int64(Int(beat) &* 7919 &+ frameIndex / 3)))
        context.saveGState()
        let slices = 3 + Int(profile.glitchStrength * 7)
        for _ in 0..<slices {
            let y = CGFloat(Double(random.nextFloat()) * Double(size.height))
            let sliceHeight = CGFloat(3 + Double(random.nextFloat()) * 26 * profile.glitchStrength)
            let offset = CGFloat((Double(random.nextFloat()) - 0.5) * Double(size.width) * 0.14 * profile.glitchStrength * burst)
            let tint = colors[1 + Int(random.nextFloat() * Float(colors.count - 1)) % max(1, colors.count - 1)]
            context.setBlendMode(.plusLighter)
            context.setFillColor(tint.withAlphaComponent(CGFloat(0.18 * burst * energy)).cgColor)
            context.fill(CGRect(x: offset, y: y, width: size.width, height: sliceHeight))
            context.setBlendMode(.multiply)
            context.setFillColor(UIColor.black.withAlphaComponent(CGFloat(0.24 * burst)).cgColor)
            context.fill(CGRect(x: -offset, y: y + sliceHeight, width: size.width, height: sliceHeight * 0.45))
        }
        context.restoreGState()
    }

    func applyColorGrade(_ context: CGContext, time: Double) {
        let drift = CGFloat(sin(time * 0.035) * 0.05)
        let warm = colors[3].shifted(hue: drift).withAlphaComponent(CGFloat(min(0.6, 0.42 * profile.warmth)))
        let cool = colors[0].shifted(hue: -drift).withAlphaComponent(0.55)
        guard let grade = gradient([warm, cool], locations: [0, 1]) else { return }
        context.saveGState()
        context.setBlendMode(.softLight)
        context.drawLinearGradient(grade,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: size.width * 0.22, y: size.height),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    /// Subtle RGB fringing that only shows near the frame edges, like a fast anamorphic lens.
    func applyEdgeChroma(_ context: CGContext) {
        guard profile.chromaEdge > 0.005 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = max(size.width, size.height) * 0.82
        let offset = CGFloat(profile.chromaEdge * 24)
        let fringes: [(UIColor, CGFloat)] = [
            (UIColor(red: 1, green: 0.18, blue: 0.28, alpha: 1), offset),
            (UIColor(red: 0.22, green: 0.5, blue: 1, alpha: 1), -offset)
        ]
        context.saveGState()
        context.setBlendMode(.screen)
        for (tint, dx) in fringes {
            let origin = CGPoint(x: center.x + dx, y: center.y)
            guard let fringe = gradient([tint.withAlphaComponent(0),
                                         tint.withAlphaComponent(0),
                                         tint.withAlphaComponent(CGFloat(profile.chromaEdge * 0.14))],
                                        locations: [0, 0.6, 1]) else { continue }
            context.drawRadialGradient(fringe,
                                       startCenter: origin,
                                       startRadius: 0,
                                       endCenter: origin,
                                       endRadius: radius,
                                       options: [.drawsAfterEndLocation])
        }
        context.restoreGState()
    }

    func applyVignette(_ context: CGContext) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let stops = [UIColor.black.withAlphaComponent(0),
                     UIColor.black.withAlphaComponent(CGFloat(profile.vignette * 0.3)),
                     UIColor.black.withAlphaComponent(CGFloat(profile.vignette))]
        guard let mask = gradient(stops, locations: [0.35, 0.75, 1]) else { return }
        context.saveGState()
        context.setBlendMode(.normal)
        context.drawRadialGradient(mask,
                                   startCenter: center,
                                   startRadius: 0,
                                   endCenter: center,
                                   endRadius: max(size.width, size.height) * 0.76,
                                   options: [.drawsAfterEndLocation])
        context.restoreGState()
    }

    func applyGrain(_ context: CGContext, frameIndex: Int) {
        guard let grain, profile.grainAmount > 0.005 else { return }
        var random = DreamRandom(seed: profile.seed &+ UInt64(bitPattern: Int64(frameIndex &* 2_654_435_761)))
        let tile = CGFloat(grain.width)
        context.saveGState()
        context.setBlendMode(.overlay)
        context.setAlpha(CGFloat(profile.grainAmount))
        context.interpolationQuality = .none
        context.draw(grain,
                     in: CGRect(x: -CGFloat(random.nextFloat()) * tile,
                                y: -CGFloat(random.nextFloat()) * tile,
                                width: tile,
                                height: tile),
                     byTiling: true)
        context.restoreGState()
    }

    static func makeGrainTile(edge: Int, seed: UInt64) -> CGImage? {
        var random = DreamRandom(seed: seed)
        var bytes = [UInt8](repeating: 128, count: edge * edge)
        for index in bytes.indices {
            bytes[index] = UInt8(max(0, min(255, 128 + Int((random.nextFloat() - 0.5) * 190))))
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: edge,
                       height: edge,
                       bitsPerComponent: 8,
                       bitsPerPixel: 8,
                       bytesPerRow: edge,
                       space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}

private extension UIColor {
    func shifted(hue hueDelta: CGFloat = 0,
                 saturation saturationScale: CGFloat = 1,
                 brightness brightnessScale: CGFloat = 1) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        var shiftedHue = (hue + hueDelta).truncatingRemainder(dividingBy: 1)
        if shiftedHue < 0 { shiftedHue += 1 }
        return UIColor(hue: shiftedHue,
                       saturation: min(max(saturation * saturationScale, 0), 1),
                       brightness: min(max(brightness * brightnessScale, 0), 1),
                       alpha: alpha)
    }
}
