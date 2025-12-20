import SwiftUI

struct LastDreamCard: View {
    let dream: SleepData
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Dream")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(dream.startedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(dream.mood.displayName)
                        .font(.title3.bold())

                    HStack(spacing: 12) {
                        Label("\(Int(dream.durationHours))h \(Int(dream.durationMinutes))m", systemImage: "bed.double.fill")
                        Label("REM \(Int(dream.remPercentage))%", systemImage: "brain.head.profile")
                    }
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                Button(action: onPlay) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 46, height: 46)
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: dream.mood.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.95)
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal)
    }
}

private extension SleepData {
    var durationHours: Double {
        let interval = endedAt.timeIntervalSince(startedAt)
        return interval / 3600
    }

    var durationMinutes: Double {
        let interval = endedAt.timeIntervalSince(startedAt)
        return (interval.truncatingRemainder(dividingBy: 3600)) / 60
    }
}
