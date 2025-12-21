import Foundation
import SwiftUI
import AVFoundation
import UIKit

final class DreamMediaComposer {
    enum Status: Equatable {
        case idle
        case preparing
        case rendering
        case completed
        case failed

        var label: String {
            switch self {
            case .idle: return "Idle"
            case .preparing: return "Analyzing"
            case .rendering: return "Rendering"
            case .completed: return "Ready"
            case .failed: return "Retry"
            }
        }

        var description: String {
            switch self {
            case .idle:
                return "Waiting for a dream session to end."
            case .preparing:
                return "Extracting REM signatures and building prompts."
            case .rendering:
                return "Synthesizing AI film and soundtrack from REM signals."
            case .completed:
                return "Dream film ready to view."
            case .failed:
                return "We couldn't finish this render. Please retry."
            }
        }
    }

    enum ComposerError: LocalizedError {
        case missingREMProfile
        case videoGenerationFailed
        case audioGenerationFailed

        var errorDescription: String? {
            switch self {
            case .missingREMProfile:
                return "No REM profile was available for this session."
            case .videoGenerationFailed:
                return "Video generation could not complete."
            case .audioGenerationFailed:
                return "Audio generation could not complete."
            }
        }
    }

    static let shared = DreamMediaComposer()
    private let cache = DreamMediaCache.shared
    private init() {}

    func composeMedia(for dream: SleepData,
                      progressHandler: (@Sendable (Double) -> Void)? = nil) async throws -> DreamVideoResult {
        guard let profile = dream.remProfile else {
            throw ComposerError.missingREMProfile
        }

        progressHandler?(0.15)
        let prompt = DreamMediaPrompt(dream: dream, profile: profile)

        let videoURL = try await synthesizeVideo(prompt: prompt, dream: dream, progressHandler: progressHandler)
        let audioURL = try await synthesizeAudio(prompt: prompt, dream: dream, progressHandler: progressHandler)
        let waveform = generateWaveform(from: prompt, duration: profile.totalDuration)
        let scenes = makeScenes(for: dream, profile: profile)
        let diagnostics = prompt.diagnostics

        progressHandler?(1.0)

        return DreamVideoResult(
            headline: "Dream Film: \(dream.mood.displayName)",
            soundtrackMood: prompt.soundtrackLabel,
            previewText: prompt.preview,
            runtime: scenes.reduce(0) { $0 + $1.duration },
            scenes: scenes,
            videoURL: videoURL,
            audioURL: audioURL,
            waveform: waveform,
            diagnostics: diagnostics
        )
    }
}

private extension DreamMediaComposer {
    func synthesizeVideo(prompt: DreamMediaPrompt,
                         dream: SleepData,
                         progressHandler: (@Sendable (Double) -> Void)?) async throws -> URL {
        let palette = prompt.palette
        let duration = max(30, prompt.profile.totalDuration)
        let fileURL = cache.makeURL(fileName: "\(dream.id.uuidString)-video", fileExtension: "mp4")

        try await VideoPlaceholderWriter.write(
            to: fileURL,
            duration: min(duration, 60),
            palette: palette
        )

        progressHandler?(0.55)
        return fileURL
    }

    func synthesizeAudio(prompt: DreamMediaPrompt,
                         dream: SleepData,
                         progressHandler: (@Sendable (Double) -> Void)?) async throws -> URL {
        let fileURL = cache.makeURL(fileName: "\(dream.id.uuidString)-score", fileExtension: "caf")
        let scoreProfile = DreamScoreProfile(dream: dream, prompt: prompt)
        try AudioPlaceholderWriter.write(
            to: fileURL,
            duration: min(prompt.profile.totalDuration, 60),
            baseFrequency: prompt.baseFrequency,
            profile: scoreProfile
        )
        progressHandler?(0.8)
        return fileURL
    }

    func generateWaveform(from prompt: DreamMediaPrompt, duration: TimeInterval) -> [Double] {
        let steps = 80
        let base = max(0.1, min(1, prompt.profile.intensityScore))
        return (0..<steps).map { index in
            let t = Double(index) / Double(steps)
            let noise = Double.random(in: -0.08...0.08)
            return clamp(base + sin(t * .pi * 2 * prompt.motionEnergy) * 0.2 + noise, low: 0, high: 1)
        }
    }

    func makeScenes(for dream: SleepData, profile: REMDreamProfile) -> [DreamVideoScene] {
        let baseStart = profile.segments.first?.start ?? dream.startedAt
        return profile.segments.enumerated().map { index, segment in
            let title: String
            let symbol: String
            switch index {
            case 0: title = "Lucid Opening"; symbol = "sparkles"
            case 1: title = "Pulse Bridge"; symbol = "waveform.path"
            default: title = "Reawakening"; symbol = "sunrise.fill"
            }
            let driverText: String
            switch segment.dominantDriver {
            case .heartRate: driverText = "Pulse surges paint the skyline."
            case .hrv: driverText = "Calm variability smooths the dream."
            case .apnea: driverText = "Breath wavers, sparks ripple."
            case .noise: driverText = "Ambient noise fractures the light."
            case .temperature: driverText = "Thermal drift bends colors."
            case .unknown: driverText = "Subconscious currents shift."
            }
            let subtitle = "HR \(Int(segment.heartRateAvg)) bpm • HRV \(Int(segment.hrvAvg)) ms. \(driverText)"
            let accent = dream.mood.colors[index % dream.mood.colors.count]
            let duration = segment.end.timeIntervalSince(segment.start)
            let offset = max(0, segment.start.timeIntervalSince(baseStart))

            return DreamVideoScene(
                title: title,
                subtitle: subtitle,
                symbol: symbol,
                accentColor: accent,
                duration: duration,
                startOffset: offset,
                remSegmentId: segment.id
            )
        }
    }
}

private struct DreamMediaPrompt {
    let dream: SleepData
    let profile: REMDreamProfile
    let palette: [UIColor]
    let motionEnergy: Double
    let soundtrackLabel: String
    let preview: String
    let baseFrequency: Double

    var diagnostics: [String: String] {
        [
            "intensity": String(format: "%.2f", profile.intensityScore),
            "moodPolarity": String(format: "%.2f", profile.moodPolarity),
            "motionEnergy": String(format: "%.2f", motionEnergy),
            "apneaSpikes": "\(profile.apneaSpikeCount)",
            "noiseSpikes": "\(profile.noiseSpikeCount)"
        ]
    }

    init(dream: SleepData, profile: REMDreamProfile) {
        self.dream = dream
        self.profile = profile
        let colors = dream.mood.colors.map { UIColor($0) }
        self.palette = colors.isEmpty ? [UIColor.systemPurple, UIColor.systemPink] : colors
        self.motionEnergy = max(0.3, min(1.6, profile.intensityScore * 1.5 + Double(profile.apneaSpikeCount) * 0.1))
        self.soundtrackLabel = "REM \(dream.mood.displayName) score"
        self.preview = "REM energy \(Int(profile.intensityScore * 100))% • mood \(String(format: "%.1f", profile.moodPolarity))"
        self.baseFrequency = 220 + Double(profile.moodPolarity * 60)
    }
}

private struct DreamScoreProfile {
    let progression: [[Float]]
    let melody: [Float]
    let countermelody: [Float]
    let ornament: [Float]
    let padSpread: [Float]
    let sceneLength: Float
    let rubatoDepth: Float
    let ornamentChance: Float
    let harpBrightness: Float
    let stringSwell: Float
    let textureLevel: Float
    let noiseFloor: Float
    let seed: UInt64

    init(dream: SleepData, prompt: DreamMediaPrompt) {
        let polarity = Float(prompt.profile.moodPolarity)
        let intensity = Float(prompt.profile.intensityScore)
        let motion = Float(prompt.motionEnergy)
        let noise = Float(prompt.profile.noiseSpikeCount)

        seed = makeSeed(from: dream.id)

        let classicalMajor: [[Float]] = [[0, 4, 7, 12], [7, 11, 14, 19], [5, 9, 12, 17], [0, 4, 7, 12]]
        let dramaticMinor: [[Float]] = [[0, 7, 10, 15], [-5, 2, 7, 12], [3, 10, 15, 19], [-2, 5, 9, 14]]
        let celestial: [[Float]] = [[0, 4, 6, 11], [5, 9, 13, 17], [2, 7, 11, 16], [-2, 4, 9, 14]]
        let restless: [[Float]] = [[0, 7, 12, 19], [-4, 3, 7, 12], [1, 8, 12, 17], [-2, 4, 9, 14]]

        let baseSets: ([[Float]], [Float], [Float], [Float])
        switch dream.mood {
        case .peaceful, .calm:
            baseSets = (classicalMajor,
                        [0, 2, 4, 7, 9, 7, 4, 2],
                        [12, 11, 9, 7, 9, 11, 12, 14],
                        [5, 7, 9, 10, 9, 7])
        case .ethereal:
            baseSets = (celestial,
                        [0, 4, 6, 7, 9, 11, 9, 7],
                        [11, 9, 7, 6, 7, 9, 11, 13],
                        [9, 11, 13, 14, 13, 11])
        case .intense, .turbulent:
            baseSets = (dramaticMinor,
                        [0, 3, 5, 7, 8, 7, 5, 3],
                        [12, 10, 8, 7, 8, 10, 12, 15],
                        [7, 8, 10, 12, 10, 8])
        case .chaotic:
            baseSets = (restless,
                        [0, 3, 1, 5, 7, 4, 6, 2],
                        [12, 14, 11, 9, 7, 9, 11, 13],
                        [2, 5, 8, 11, 8, 5])
        }

        let rotationMelody = Int(seed % UInt64(max(baseSets.1.count, 1)))
        let rotationCounter = Int((seed >> 5) % UInt64(max(baseSets.2.count, 1)))
        let rotationOrnament = Int((seed >> 9) % UInt64(max(baseSets.3.count, 1)))
        let rotationProg = Int((seed >> 13) % UInt64(max(baseSets.0.count, 1)))

        progression = Self.rotated(baseSets.0, offset: rotationProg)
        melody = Self.rotated(baseSets.1, offset: rotationMelody)
        countermelody = Self.rotated(baseSets.2, offset: rotationCounter)
        ornament = Self.rotated(baseSets.3, offset: rotationOrnament)

        padSpread = [
            -0.18 - intensity * 0.05,
            0.02 + polarity * 0.04,
            0.18 + intensity * 0.09
        ]

        sceneLength = max(3.8, min(7.5, 4.4 + motion * 1.3 + intensity * 2.6))
        rubatoDepth = max(0.25, min(0.85, 0.3 + motion * 0.28 + abs(polarity) * 0.18))
        ornamentChance = max(0.05, min(0.6, 0.12 + intensity * 0.3 + abs(polarity) * 0.2))
        harpBrightness = max(0.6, min(1.35, 0.85 + polarity * 0.25 + motion * 0.1))
        stringSwell = max(0.45, min(1.2, 0.55 + motion * 0.35 + intensity * 0.15))
        textureLevel = max(0.004, min(0.02, 0.006 + noise * 0.001 + intensity * 0.006))
        noiseFloor = max(0.002, min(0.008, 0.003 + noise * 0.0008 + intensity * 0.0008))
    }

    private static func rotated(_ values: [Float], offset: Int) -> [Float] {
        guard !values.isEmpty else { return [] }
        let normalized = ((offset % values.count) + values.count) % values.count
        if normalized == 0 { return values }
        let head = Array(values[normalized...])
        let tail = Array(values[..<normalized])
        return head + tail
    }

    private static func rotated(_ values: [[Float]], offset: Int) -> [[Float]] {
        guard !values.isEmpty else { return [] }
        let normalized = ((offset % values.count) + values.count) % values.count
        if normalized == 0 { return values }
        let head = Array(values[normalized...])
        let tail = Array(values[..<normalized])
        return head + tail
    }
}

private final class DreamMediaCache {
    static let shared = DreamMediaCache()
    private let directory: URL
    private let fileManager = FileManager.default

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = caches.appendingPathComponent("DreamMediaCache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func makeURL(fileName: String, fileExtension: String) -> URL {
        directory.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
    }
}

private enum VideoPlaceholderWriter {
    static func write(to url: URL, duration: TimeInterval, palette: [UIColor]) async throws {
        let width = 640
        let height = 360
        let assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        writerInput.expectsMediaDataInRealTime = false
        guard assetWriter.canAdd(writerInput) else { throw DreamMediaComposer.ComposerError.videoGenerationFailed }
        assetWriter.add(writerInput)

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput,
                                                           sourcePixelBufferAttributes: attributes)
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        let fps: Double = 24
        let totalFrames = max(1, Int(duration * fps))
        for frameIndex in 0..<totalFrames {
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            if let buffer = makePixelBuffer(palette: palette, phase: Double(frameIndex) / Double(totalFrames)) {
                adaptor.append(buffer, withPresentationTime: presentationTime)
            }
        }

        writerInput.markAsFinished()
        await assetWriter.finishWriting()
    }

    static func makePixelBuffer(palette: [UIColor], phase: Double) -> CVPixelBuffer? {
        let width = 640
        let height = 360
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        let uiColors = palette.isEmpty ? [UIColor.systemPurple, UIColor.systemPink, UIColor.systemIndigo] : palette
        let colors = uiColors.map { $0.cgColor }
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) else {
            return nil
        }
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: CGFloat(height)),
                                   options: [])

        let size = CGSize(width: width, height: height)
        drawLightHaze(context: context, size: size, phase: phase)
        drawAuroraBands(context: context, size: size, palette: uiColors, phase: phase)
        drawOrbitalTrails(context: context, size: size, palette: uiColors, phase: phase)
        drawDreamRibbons(context: context, size: size, palette: uiColors, phase: phase)
        drawPulseNebula(context: context, size: size, palette: uiColors, phase: phase)
        drawStarlightField(context: context, size: size, palette: uiColors, phase: phase)
        drawSpecularHighlights(context: context, size: size, palette: uiColors, phase: phase)
        overlayGlyphGrid(context: context, size: size, phase: phase)
        overlayStaffLines(context: context, size: size, phase: phase)
        applyLensBloom(context: context, size: size, phase: phase)

        return buffer
    }

    static func drawLightHaze(context: CGContext, size: CGSize, phase: Double) {
        context.saveGState()
        let center = CGPoint(x: size.width * 0.5, y: size.height * (0.3 + CGFloat(sin(phase * 2 * .pi)) * 0.1))
        let colors = [UIColor.white.withAlphaComponent(0.15).cgColor,
                      UIColor.clear.cgColor]
        if let haze = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            context.drawRadialGradient(haze,
                                       startCenter: center,
                                       startRadius: 0,
                                       endCenter: center,
                                       endRadius: max(size.width, size.height) * 0.8,
                                       options: .drawsAfterEndLocation)
        }
        context.restoreGState()
    }

    static func drawDreamRibbons(context: CGContext, size: CGSize, palette: [UIColor], phase: Double) {
        let ribbonCount = 3
        let steps = 80
        for index in 0..<ribbonCount {
            let color = palette[index % palette.count].withAlphaComponent(0.45).cgColor
            let path = UIBezierPath()
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let x = CGFloat(progress) * size.width
                let wave = sin(progress * .pi * Double(index + 2) + phase * 2 * .pi)
                let arc = cos(phase * Double(index + 1) * 1.3) * 0.2
                let y = size.height * (0.5 + CGFloat(wave) * 0.2 + CGFloat(arc) * 0.15)
                if step == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.addPath(path.cgPath)
            context.setLineWidth(CGFloat(1.5 + Double(index)))
            context.setStrokeColor(color)
            context.strokePath()
        }
    }

    static func drawSpecularHighlights(context: CGContext, size: CGSize, palette: [UIColor], phase: Double) {
        context.saveGState()
        let highlightCount = 24
        for index in 0..<highlightCount {
            let t = (Double(index) / Double(highlightCount)) + phase
            let normalized = t - floor(t)
            let x = CGFloat(normalized) * size.width
            let y = size.height * (0.2 + CGFloat(abs(sin((phase + Double(index)) * 2 * .pi))) * 0.6)
            let radius = CGFloat(2.0 + sin((phase * 3) + Double(index)) * 1.5)
            let color = palette[index % palette.count].withAlphaComponent(0.35).cgColor
            context.setFillColor(color)
            context.fillEllipse(in: CGRect(x: x - radius,
                                           y: y - radius,
                                           width: radius * 2,
                                           height: radius * 2))
        }
        context.restoreGState()
    }

    static func drawOrbitalTrails(context: CGContext, size: CGSize, palette: [UIColor], phase: Double) {
        context.saveGState()
        let trailCount = 5
        for index in 0..<trailCount {
            let normalized = Double(index) / Double(trailCount)
            let radius = size.width * 0.18 + CGFloat(normalized) * size.width * 0.12
            let center = CGPoint(x: size.width * 0.5 + CGFloat(sin(phase * 1.3 + normalized * 2)) * 40,
                                 y: size.height * 0.55 + CGFloat(cos(phase * 1.1 + normalized * 2)) * 20)
            let path = UIBezierPath(ovalIn: CGRect(x: center.x - radius,
                                                   y: center.y - radius * 0.4,
                                                   width: radius * 2,
                                                   height: radius * 0.8))
            context.setStrokeColor(palette[index % palette.count].withAlphaComponent(0.25).cgColor)
            context.setLineWidth(CGFloat(0.8 + normalized))
            context.addPath(path.cgPath)
            context.strokePath()

            let bodyAngle = CGFloat(phase * 4 + normalized * 6)
            let dotX = center.x + cos(bodyAngle) * radius
            let dotY = center.y + sin(bodyAngle) * radius * 0.4
            let dotRect = CGRect(x: dotX - 3, y: dotY - 3, width: 6, height: 6)
            context.setFillColor(UIColor.white.withAlphaComponent(0.4).cgColor)
            context.fillEllipse(in: dotRect)
        }
        context.restoreGState()
    }

    static func drawStarlightField(context: CGContext, size: CGSize, palette: [UIColor], phase: Double) {
        context.saveGState()
        let starCount = 70
        for index in 0..<starCount {
            let t = Double(index) / Double(starCount)
            let flicker = CGFloat(0.15 + 0.1 * sin(phase * 5 + t * 40))
            let x = CGFloat((sin(t * 89 + phase * 1.3) + 1) * 0.5) * size.width
            let y = CGFloat((cos(t * 53 + phase * 0.9) + 1) * 0.5) * size.height
            let rect = CGRect(x: x, y: y, width: 1.5 + flicker, height: 1.5 + flicker)
            let color = palette[index % palette.count].withAlphaComponent(0.25 + 0.2 * flicker).cgColor
            context.setFillColor(color)
            context.fillEllipse(in: rect)
        }
        context.restoreGState()
    }

    static func overlayStaffLines(context: CGContext, size: CGSize, phase: Double) {
        context.saveGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(0.6)
        let staffHeight = size.height * 0.4
        let spacing = staffHeight / 10
        let offsetY = size.height * 0.15 + CGFloat(sin(phase * 2)) * 12
        for line in 0..<5 {
            let y = offsetY + CGFloat(line) * spacing
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.strokePath()
        context.restoreGState()
    }

    static func drawAuroraBands(context: CGContext, size: CGSize, palette: [UIColor], phase: Double) {
        context.saveGState()
        let layers = 4
        for index in 0..<layers {
            let hueShift = Double(index) / Double(layers)
            let color = palette[index % palette.count].withAlphaComponent(0.35).cgColor
            let path = UIBezierPath()
            let steps = 120
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let x = CGFloat(progress) * size.width
                let wave = sin(progress * .pi * (1.6 + hueShift) + phase * 3)
                let drift = cos((phase + hueShift) * 2 * .pi) * 0.15
                let y = size.height * (0.2 + CGFloat(wave) * 0.12 + CGFloat(drift))
                if step == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.addPath(path.cgPath)
            context.setLineWidth(CGFloat(4 - index))
            context.setShadow(offset: .zero, blur: CGFloat(15 - index * 3), color: color)
            context.setStrokeColor(color)
            context.strokePath()
        }
        context.restoreGState()
    }

    static func drawPulseNebula(context: CGContext, size: CGSize, palette: [UIColor], phase: Double) {
        context.saveGState()
        let center = CGPoint(x: size.width * 0.5, y: size.height * (0.55 + CGFloat(sin(phase * 1.7)) * 0.05))
        for index in 0..<3 {
            let pulse = CGFloat(1 + sin(phase * Double(index + 2) * 2 * .pi) * 0.25)
            let radius = max(size.width, size.height) * (0.25 + CGFloat(index) * 0.2) * pulse
            let colors = [palette[(index + 1) % palette.count].withAlphaComponent(0.25).cgColor,
                          UIColor.clear.cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.drawRadialGradient(gradient,
                                           startCenter: center,
                                           startRadius: 0,
                                           endCenter: center,
                                           endRadius: radius,
                                           options: .drawsAfterEndLocation)
            }
        }
        context.restoreGState()
    }

    static func overlayGlyphGrid(context: CGContext, size: CGSize, phase: Double) {
        context.saveGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(0.5)
        let columns = 5
        let rows = 3
        for row in 0..<rows {
            for column in 0..<columns {
                let cellWidth = size.width / CGFloat(columns)
                let cellHeight = size.height / CGFloat(rows)
                let origin = CGPoint(x: CGFloat(column) * cellWidth, y: CGFloat(row) * cellHeight)
                let inset = CGFloat(8 + (sin(phase * 4 + Double(row + column)) + 1) * 4)
                let rect = CGRect(x: origin.x + inset,
                                  y: origin.y + inset,
                                  width: cellWidth - inset * 2,
                                  height: cellHeight - inset * 2)
                context.stroke(rect)
            }
        }
        context.restoreGState()
    }

    static func applyLensBloom(context: CGContext, size: CGSize, phase: Double) {
        context.saveGState()
        let bloomRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.setFillColor(UIColor.white.withAlphaComponent(0.05 + CGFloat(0.02 * sin(phase * 6))).cgColor)
        context.fill(bloomRect)
        context.setBlendMode(.screen)
        let sweepY = size.height * (0.3 + CGFloat(phase) * 0.4)
        context.setFillColor(UIColor.white.withAlphaComponent(0.12).cgColor)
        context.fill(CGRect(x: 0, y: sweepY, width: size.width, height: 20))
        context.restoreGState()
    }
}

private enum AudioPlaceholderWriter {
    static func write(to url: URL,
                      duration: TimeInterval,
                      baseFrequency: Double,
                      profile: DreamScoreProfile) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let totalFrames = AVAudioFrameCount(max(1, Int(duration * format.sampleRate)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            throw DreamMediaComposer.ComposerError.audioGenerationFailed
        }
        buffer.frameLength = totalFrames
        let channelData = buffer.floatChannelData![0]
        let sampleRate = Float(format.sampleRate)
        let totalDuration = max(Float(duration), 0.1)
        let base = Float(baseFrequency)
        let sceneLength = max(3.5, profile.sceneLength)
        let progression: [[Float]] = profile.progression.isEmpty ? [[0, 7, 12, 19]] : profile.progression
        let melodyPhrase: [Float] = profile.melody.isEmpty ? [0, 2, 4, 5, 7, 5, 4, 2] : profile.melody
        let counterPhrase: [Float] = profile.countermelody.isEmpty ? [12, 11, 9, 7, 9, 11, 12, 14] : profile.countermelody
        let ornamentPhrase: [Float] = profile.ornament.isEmpty ? [5, 7, 9, 10, 9, 7] : profile.ornament
        let padDetune: [Float] = profile.padSpread.isEmpty ? [-0.18, 0.07, 0.21] : profile.padSpread
        let rubatoDepth = profile.rubatoDepth
        let ornamentChance = min(max(profile.ornamentChance, 0), 0.75)
        let stringSwell = profile.stringSwell
        let harpBrightness = profile.harpBrightness
        let textureLevel = profile.textureLevel
        let noiseFloor = profile.noiseFloor
        var bassFilter = OnePoleFilter(coefficient: 0.018)
        var airFilter = OnePoleFilter(coefficient: 0.12)
        var shimmerFilter = OnePoleFilter(coefficient: 0.05)
        var textureFilter = OnePoleFilter(coefficient: 0.08)
        var shimmerDelay = DreamDelay(sampleRate: sampleRate,
                                      time: 0.32 + 0.12 * rubatoDepth,
                                      feedback: 0.45 + 0.05 * rubatoDepth)
        var cloudDelay = DreamDelay(sampleRate: sampleRate,
                                    time: 0.58 + 0.08 * stringSwell,
                                    feedback: 0.54)
        var random = DreamRandom(seed: profile.seed)

        for frame in 0..<Int(totalFrames) {
            let t = Float(frame) / sampleRate
            let scenePosition = t / sceneLength
            let sceneIndex = Int(scenePosition)
            let chord = progression[sceneIndex % progression.count]
            let progress = scenePosition - floor(scenePosition)

            let macroLFO = sin(t * (0.1 + rubatoDepth * 0.2))
            let shimmerLFO = sin(t * (1.5 + rubatoDepth * 0.45))
            let wow = 1 + (0.0015 + rubatoDepth * 0.001) * sin(t * 0.35 + sin(t * 0.08))
            let padGain = 0.05 + stringSwell * 0.05
            let pad = padDetune.reduce(Float(0)) { sum, detune in
                let spread = chord.reduce(Float(0)) { chordSum, interval in
                    chordSum + waveform(.sine,
                                         frequency: semitone(base: base * wow * (1 + detune * 0.002), semitone: interval),
                                         time: t + detune * 0.002,
                                         vibrato: macroLFO * 0.2)
                }
                return sum + spread * padGain
            }

            let arpIndex = Int(progress * Float(chord.count * 2)) % chord.count
            let arpGate = smoothGate(progress)
            let arpFreq = semitone(base: base * 2, semitone: chord[arpIndex] + 12)
            let arp = waveform(.triangle,
                               frequency: arpFreq,
                               time: t * (1.3 + 0.2 * sin(t * 0.25)),
                               vibrato: shimmerLFO * 0.05) * (0.18 + stringSwell * 0.05) * arpGate

            let melodyStep = Int(progress * Float(melodyPhrase.count))
            let melodyNote = melodyPhrase[melodyStep % melodyPhrase.count]
            let melodyFreq = semitone(base: base, semitone: melodyNote + 12)
            let melodyEnv = classicalPhraseEnvelope(progress: progress)
            let melody = waveform(.sine,
                                   frequency: melodyFreq,
                                   time: t + 0.001 * sin(t * 0.6),
                                   vibrato: 0.02 * sin(t * 0.3)) * (0.28 + harpBrightness * 0.04) * melodyEnv

            let counterIndex = (melodyStep + sceneIndex) % counterPhrase.count
            let counterFreq = semitone(base: base * 0.5, semitone: counterPhrase[counterIndex])
            let counterEnv = 0.6 + 0.4 * sin(progress * .pi)
            let counter = waveform(.triangle,
                                   frequency: counterFreq,
                                   time: t * 0.8,
                                   vibrato: macroLFO * 0.05) * (0.18 + stringSwell * 0.06) * counterEnv

            let bassFreq = semitone(base: base * 0.5, semitone: chord[0] - 12)
            let rawBass = waveform(.saw,
                                   frequency: bassFreq * (1 + 0.005 * sin(t * 0.6)),
                                   time: t,
                                   vibrato: 0) * 0.35
            let bass = bassFilter.process(rawBass)

            let shimmerHarm = waveform(.sine,
                                       frequency: semitone(base: base * 3, semitone: chord[1] + 7),
                                       time: t,
                                       vibrato: shimmerLFO * 0.1) * 0.18
            let shimmer = shimmerFilter.process(shimmerHarm)

            let choirFreq = semitone(base: base * 0.5, semitone: chord[0])
            let choir = waveform(.sine,
                                 frequency: choirFreq,
                                 time: t,
                                 vibrato: sin(t * 0.05) * 0.3) * (0.16 + stringSwell * 0.05)

            let harpBeat = fmod(progress * 2, 1)
            let harpEnv = pluckEnvelope(harpBeat)
            let harpFreq = semitone(base: base * 2.8, semitone: chord[arpIndex])
            let harp = waveform(.saw,
                                frequency: harpFreq,
                                time: t,
                                vibrato: 0) * (0.1 * harpBrightness) * harpEnv

            var ornamentVoice: Float = 0
            if ornamentChance > 0 {
                let ornamentBeat = fmod(progress * 2.5 + Float(sceneIndex) * 0.17, 1)
                if ornamentBeat < ornamentChance {
                    let ornamentStep = Int(progress * Float(ornamentPhrase.count))
                    let ornamentNote = ornamentPhrase[ornamentStep % ornamentPhrase.count]
                    let ornamentFreq = semitone(base: base * 3, semitone: ornamentNote)
                    let ornamentEnv = pluckEnvelope(ornamentBeat / max(ornamentChance, 0.001))
                    ornamentVoice = waveform(.triangle,
                                             frequency: ornamentFreq,
                                             time: t * (1.5 + rubatoDepth * 0.3),
                                             vibrato: shimmerLFO * 0.04) * 0.14 * ornamentEnv
                }
            }

            let texture = textureFilter.process((random.nextFloat() * 2 - 1) * textureLevel + sin(t * 0.33) * textureLevel * 0.8)
            let air = airFilter.process((random.nextFloat() * 2 - 1) * (textureLevel * 0.6))

            let pulse = sin(Float.pi * 2 * 0.33 * t) * 0.04

            let attack = min(1, t / 3)
            let release = min(1, max(0, (totalDuration - t) / 3.5))
            let sceneAccent = min(1.2, max(0.55, 0.72 + 0.18 * sin(Float(sceneIndex) * 0.7) + rubatoDepth * 0.15))
            var signal = (pad + arp + bass + choir + melody + counter + shimmer + harp + ornamentVoice + texture + air + pulse) * attack * release * sceneAccent
            let wet = signal
            signal += shimmerDelay.process(wet * 0.6)
            signal += cloudDelay.process(wet * 0.4)
            let hiss = (random.nextFloat() * 2 - 1) * noiseFloor
            channelData[frame] = softClip(signal + hiss)
        }
        try file.write(from: buffer)
    }
}

private enum WaveShape {
    case sine
    case triangle
    case saw
}

private func waveform(_ shape: WaveShape, frequency: Float, time: Float, vibrato: Float) -> Float {
    let twoPi = Float.pi * 2
    let phase = twoPi * frequency * (time + vibrato * 0.002)
    switch shape {
    case .sine:
        return sin(phase)
    case .triangle:
        let cycle = phase / twoPi
        let frac = cycle - Float(floor(Double(cycle)))
        return 2 * abs(2 * frac - 1) - 1
    case .saw:
        let value = fmod(phase, twoPi) / twoPi
        return (value * 2) - 1
    }
}

private func semitone(base: Float, semitone: Float) -> Float {
    base * powf(2, semitone / 12)
}

private func smoothGate(_ progress: Float) -> Float {
    max(0, sin(progress * Float.pi))
}

private func softClip(_ value: Float) -> Float {
    tanhf(value * 0.9)
}

private func classicalPhraseEnvelope(progress: Float) -> Float {
    let rise = min(progress / 0.25, 1)
    let fall = min(max(0, 1 - progress) / 0.35, 1)
    return max(0, rise * fall)
}

private func pluckEnvelope(_ progress: Float) -> Float {
    max(0, powf(1 - progress, 3))
}

private struct DreamDelay {
    private var buffer: [Float]
    private var index: Int = 0
    private let feedback: Float

    init(sampleRate: Float, time: Float, feedback: Float) {
        let length = max(1, Int(sampleRate * time))
        self.buffer = Array(repeating: 0, count: length)
        self.feedback = feedback
    }

    mutating func process(_ input: Float) -> Float {
        let output = buffer[index]
        buffer[index] = input + output * feedback
        index = (index + 1) % buffer.count
        return output
    }
}

private struct OnePoleFilter {
    var value: Float = 0
    let coefficient: Float

    mutating func process(_ input: Float) -> Float {
        value += coefficient * (input - value)
        return value
    }
}

private struct DreamRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x123456789ABCDEF : seed
    }

    mutating func nextFloat() -> Float {
        state = state &* 6364136223846793005 &+ 1
        let result = Float((state >> 33) & 0xFFFFFFFF) / Float(UInt32.max)
        return result
    }
}

private func makeSeed(from uuid: UUID) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    withUnsafeBytes(of: uuid.uuid) { bytes in
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
    }
    return hash
}

private func clamp(_ value: Double, low: Double, high: Double) -> Double {
    min(max(value, low), high)
}