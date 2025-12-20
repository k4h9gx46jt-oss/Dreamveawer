import SwiftUI

struct LastDreamCard: View {
    let dream: SleepData
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Dream")
                    .font(.headline)
                Spacer()
                Text(dream.startedAt, style: .relative)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(dream.mood.displayName)
                    .font(.title2.bold())
                Label("REM \(Int(dream.remPercentage))%", systemImage: "brain.head.profile")
                    .foregroundStyle(.secondary)
                Label("Average \(Int(dream.averageHeartRate)) BPM", systemImage: "heart.fill")
                    .foregroundStyle(.secondary)
            }
            Button(action: onPlay) {
                Label("View Dream", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            LinearGradient(colors: dream.mood.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal)
    }
}
