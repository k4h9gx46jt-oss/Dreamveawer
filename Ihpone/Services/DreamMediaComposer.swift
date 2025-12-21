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
        try AudioPlaceholderWriter.write(
            to: fileURL,
            duration: min(prompt.profile.totalDuration, 60),
            baseFrequency: prompt.baseFrequency
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
        drawDreamRibbons(context: context, size: size, palette: uiColors, phase: phase)
        drawSpecularHighlights(context: context, size: size, palette: uiColors, phase: phase)

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
}

private enum AudioPlaceholderWriter {
    static func write(to url: URL, duration: TimeInterval, baseFrequency: Double) throws {
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
        let padIntervals: [Float] = [1.0, 1.25, 1.5, 1.75]
        let pulseIntervals: [Float] = [2.0, 1.5, 2.5]
        let bassIntervals: [Float] = [0.5, 0.75, 1.0]
        let sceneLength: Float = 4.5
        let base = Float(baseFrequency)
        let twoPi = Float.pi * 2
        for frame in 0..<Int(totalFrames) {
            let t = Float(frame) / sampleRate
            let sceneIndex = Int(t / sceneLength)
            let padFreq = base * padIntervals[sceneIndex % padIntervals.count]
            let pulseFreq = base * pulseIntervals[sceneIndex % pulseIntervals.count]
            let bassFreq = base * bassIntervals[sceneIndex % bassIntervals.count]

            let pad = sin(twoPi * padFreq * t + sin(t * 0.35) * 0.6) * 0.45
            let arp = sin(twoPi * pulseFreq * t * (0.7 + 0.3 * sin(t * 0.5))) * 0.25
            let shimmer = sin(twoPi * (padFreq * 3) * t + sin(t * 1.5)) * 0.12
            let bass = sin(twoPi * bassFreq * t) * 0.2
            let texture = (sin(twoPi * t * 0.3) + sin(twoPi * t * 0.57)) * 0.03

            let attack = min(1, t / 2)
            let release = min(1, max(0, (totalDuration - t) / 2.5))
            let sceneAccent = 0.85 + 0.15 * sin(Float(sceneIndex) + t * 0.4)
            let envelope = attack * release * sceneAccent

            let signal = (pad + arp + shimmer + bass) * envelope + texture
            channelData[frame] = max(-0.95, min(0.95, signal * 0.7))
        }
        try file.write(from: buffer)
    }
}

private func clamp(_ value: Double, low: Double, high: Double) -> Double {
    min(max(value, low), high)
}