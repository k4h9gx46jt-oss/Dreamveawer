import SwiftUI

struct DreamVideoView: View {
    let result: DreamVideoResult
    @Environment(\.dismiss) private var dismiss
    @State private var activeScene = 0

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
        }
    }
}

private extension DreamVideoView {
    var heroPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32)
                .fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 220)
                .overlay(
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            let time = timeline.date.timeIntervalSinceReferenceDate
                            for index in 0..<18 {
                                let progress = (time + Double(index)).truncatingRemainder(dividingBy: 6) / 6
                                let x = size.width * progress
                                let y = sin(progress * .pi * 2 + Double(index)) * 30 + size.height / 2
                                let rect = CGRect(x: x, y: y, width: 8, height: 8)
                                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.35)))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                )

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
                Image(systemName: "music.quarternote.3")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Soundtrack")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(result.soundtrackMood)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()
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
                Text("\(Int(scene.duration))s")
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
