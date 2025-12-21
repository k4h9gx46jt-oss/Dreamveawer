import SwiftUI
import AVKit
import AVFoundation

struct DreamVideoView: View {
    let result: DreamVideoResult
    @Environment(\.dismiss) private var dismiss
    @State private var activeScene = 0
    @State private var videoPlayer: AVPlayer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioProgress: Double = 0
    @State private var audioDuration: TimeInterval = 1
    @State private var audioTimer: Timer?
    @State private var isAudioScrubbing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                heroPreview
                scenePager
                sceneTimeline
                soundtrackCard
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle("AI Dream Video")
            .navigationBarTitleDisplayMode(.inline)
            .background(LinearGradient(colors: [.black, Color(hex: 0x1a1037)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .onAppear(perform: setupMedia)
            .onDisappear(perform: teardownMedia)
        }
    }
}

private extension DreamVideoView {
    var heroPreview: some View {
        ZStack(alignment: .bottomLeading) {
            if let player = videoPlayer {
                VideoPlayer(player: player)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .overlay(alignment: .topTrailing) {
                        Button(action: toggleVideoPlayback) {
                            Image(systemName: player.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(12)
                    }
            } else {
                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 220)
                    .overlay(AnimatedParticles().clipShape(RoundedRectangle(cornerRadius: 32)))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(result.headline)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(result.previewText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Label("\(Int(result.runtime)) sec runtime", systemImage: "clock")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding()
        }
    }

    var scenePager: some View {
        TabView(selection: $activeScene) {
            ForEach(Array(result.scenes.enumerated()), id: \.offset) { index, scene in
                DreamVideoSceneCard(scene: scene)
                    .tag(index)
                    .padding(.horizontal, 4)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 260)
    }

    var sceneTimeline: some View {
        VStack(alignment: .leading) {
            Text("Scene Timeline")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                ForEach(Array(result.scenes.enumerated()), id: \.offset) { index, scene in
                    let isActive = index == activeScene
                    VStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(scene.accentColor.opacity(isActive ? 1 : 0.4))
                            .frame(height: isActive ? 16 : 8)
                            .overlay(alignment: .trailing) {
                                Text("\(Int(scene.startOffset))s")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        Text(scene.title)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(isActive ? 1 : 0.6))
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }

    var soundtrackCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(palette.first ?? .purple)
                    .frame(width: 56, height: 56)
                Image(systemName: audioPlayer?.isPlaying == true ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .onTapGesture { toggleAudioPlayback() }

            VStack(alignment: .leading, spacing: 4) {
                Text("Soundtrack")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(result.soundtrackMood)
                    .foregroundStyle(.white.opacity(0.7))
                if audioPlayer != nil {
                    if !result.waveform.isEmpty {
                        AudioWaveformView(values: result.waveform, progress: audioProgress)
                            .frame(height: 40)
                    }
                    Slider(value: Binding(get: {
                        audioProgress
                    }, set: { newValue in
                        audioProgress = newValue
                        guard isAudioScrubbing, let player = audioPlayer else { return }
                        player.currentTime = newValue * audioDuration
                    }), in: 0...1, onEditingChanged: { editing in
                        isAudioScrubbing = editing
                        if !editing, let player = audioPlayer {
                            player.currentTime = audioProgress * audioDuration
                        }
                    })
                    .tint(.white)
                } else {
                    Text("Audio render pending")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if audioPlayer != nil {
                VStack(alignment: .trailing) {
                    Text(formattedTime(audioProgress * audioDuration))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(formattedTime(audioDuration))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding()
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    var palette: [Color] {
        if let firstScene = result.scenes.first {
            return [firstScene.accentColor, firstScene.accentColor.opacity(0.4)]
        }
        return [.purple, .pink]
    }
}

private struct DreamVideoSceneCard: View {
    let scene: DreamVideoScene

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: scene.symbol)
                    .font(.title2)
                Text(scene.title)
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Int(scene.duration))s")
                        .font(.subheadline)
                    Text("Start \(Int(scene.startOffset))s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)

            Text(scene.subtitle)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(scene.accentColor.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

private extension DreamVideoView {
    func setupMedia() {
        if let videoURL = result.videoURL {
            let player = AVPlayer(url: videoURL)
            player.play()
            player.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                player.seek(to: .zero)
                player.play()
            }
            videoPlayer = player
        }

        if let audioURL = result.audioURL {
            do {
                let audio = try AVAudioPlayer(contentsOf: audioURL)
                audio.numberOfLoops = -1
                audio.play()
                audioDuration = audio.duration
                audioPlayer = audio
                startAudioTimer()
            } catch {
                print("Audio playback failed: \(error.localizedDescription)")
            }
        }
    }

    func teardownMedia() {
        videoPlayer?.pause()
        videoPlayer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        audioTimer?.invalidate()
        audioTimer = nil
    }

    func toggleVideoPlayback() {
        guard let player = videoPlayer else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func toggleAudioPlayback() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func startAudioTimer() {
        audioTimer?.invalidate()
        audioTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            guard let player = audioPlayer, !isAudioScrubbing else { return }
            audioProgress = (player.duration == 0) ? 0 : player.currentTime / player.duration
        }
    }

    func formattedTime(_ value: TimeInterval) -> String {
        let minutes = Int(value) / 60
        let seconds = Int(value) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct AudioWaveformView: View {
    let values: [Double]
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let waveform = values.isEmpty ? [0.3] : values
            let step = waveform.count
            let barWidth = width / CGFloat(step)

            ZStack(alignment: .leading) {
                Path { path in
                    for (index, value) in waveform.enumerated() {
                        let x = CGFloat(index) * barWidth
                        let barHeight = CGFloat(max(0.05, value)) * height
                        path.move(to: CGPoint(x: x, y: (height - barHeight) / 2))
                        path.addLine(to: CGPoint(x: x, y: (height + barHeight) / 2))
                    }
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1)

                Rectangle()
                    .fill(LinearGradient(colors: [.white, .white.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width * progress)
                    .mask(
                        Path { path in
                            for (index, value) in waveform.enumerated() {
                                let x = CGFloat(index) * barWidth
                                let barHeight = CGFloat(max(0.05, value)) * height
                                path.move(to: CGPoint(x: x, y: (height - barHeight) / 2))
                                path.addLine(to: CGPoint(x: x, y: (height + barHeight) / 2))
                            }
                        }
                        .stroke(lineWidth: 1.5)
                    )
            }
        }
    }
}

private struct AnimatedParticles: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<20 {
                    let progress = (time + Double(index)).truncatingRemainder(dividingBy: 5) / 5
                    let x = size.width * progress
                    let y = sin(progress * .pi * 2 + Double(index)) * 30 + size.height / 2
                    let rect = CGRect(x: x, y: y, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.35)))
                }
            }
        }
    }
}
