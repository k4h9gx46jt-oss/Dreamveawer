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
        let assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 640,
            AVVideoHeightKey: 360
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        writerInput.expectsMediaDataInRealTime = false
        guard assetWriter.canAdd(writerInput) else { throw DreamMediaComposer.ComposerError.videoGenerationFailed }
        assetWriter.add(writerInput)

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: 640,
            kCVPixelBufferHeightKey as String: 360
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
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 640, 360, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
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

        let colors = palette.isEmpty ? [UIColor.systemPurple.cgColor, UIColor.systemPink.cgColor] : palette.map { $0.cgColor }
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) else {
            return nil
        }
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: CGFloat(CVPixelBufferGetHeight(buffer))),
                                   options: [])

        context.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        let dots = 18
        for index in 0..<dots {
            let t = Double(index) / Double(dots)
            let x = CGFloat(t * Double(CVPixelBufferGetWidth(buffer)))
            let y = CGFloat(abs(sin(phase * .pi * 2 + t * .pi)))*120 + 120
            let rect = CGRect(x: x, y: y, width: 6, height: 6)
            context.fillEllipse(in: rect)
        }

        return buffer
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
        let modulation = Float.random(in: 0.4...0.9)
        for frame in 0..<Int(totalFrames) {
            let progress = Float(frame) / Float(totalFrames)
            let vibrato = sin(progress * Float.pi * 6) * 6
            let freq = Float(baseFrequency) * (0.9 + modulation * sin(progress * Float.pi * 2)) + vibrato
            channelData[frame] = sin(2 * .pi * freq * Float(frame) / Float(format.sampleRate)) * 0.16
        }
        try file.write(from: buffer)
    }
}

private func clamp(_ value: Double, low: Double, high: Double) -> Double {
    min(max(value, low), high)
}