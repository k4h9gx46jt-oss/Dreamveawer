import SwiftUI

struct DreamDashboardView: View {
    let lastDream: SleepData?
    let history: [SleepData]
    let startTapped: () -> Void
    let dreamTapped: (SleepData) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                if let dream = lastDream {
                    LastDreamCard(dream: dream) {
                        dreamTapped(dream)
                    }
                }
                Text("Dream History")
                    .font(.title3.bold())
                    .padding(.horizontal)
                VStack(spacing: 12) {
                    ForEach(history) { dream in
                        DreamHistoryRow(dream: dream)
                            .onTapGesture { dreamTapped(dream) }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var heroCard: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Color(hex: 0x7F7FD5), Color(hex: 0x86A8E7), Color(hex: 0x91EAE4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(30)
            VStack(alignment: .leading, spacing: 12) {
                Label("Start Dream Mode", systemImage: "bed.double.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Track your sleep and visualize your dreams")
                    .foregroundStyle(.white.opacity(0.9))
                Button(action: startTapped) {
                    HStack {
                        Text("Begin" )
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
                }
            }
            .padding(30)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }
}

private struct DreamHistoryRow: View {
    let dream: SleepData

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: dream.mood.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: dream.mood.icon).foregroundStyle(.white))
            VStack(alignment: .leading) {
                Text(dream.mood.displayName)
                    .font(.headline)
                Text(dream.startedAt, style: .date)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
