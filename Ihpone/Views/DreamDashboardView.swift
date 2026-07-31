import SwiftUI

struct DreamDashboardView: View {
    let lastDream: SleepData?
    let history: [SleepData]
    let startTapped: () -> Void
    let dreamTapped: (SleepData) -> Void
    let isRemoteSessionActive: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.88, blue: 1.0),
                    Color(red: 0.92, green: 0.80, blue: 1.0),
                    Color(red: 0.84, green: 0.72, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
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
                    .padding(.bottom, 24)
                }
                .padding(.top, 32)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DreamWeaver")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(.black)
                .padding(.horizontal)

            VStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.20))
                Text("See What Your Mind Creates")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var heroCard: some View {
        Button(action: startTapped) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: isRemoteSessionActive ? "waveform.path.ecg" : "bed.double.fill")
                            .font(.title2)
                        Text(isRemoteSessionActive ? "Dreaming" : "Open Dream Monitor")
                            .font(.title2.bold())
                    }
                    .foregroundStyle(.white)

                    Text(isRemoteSessionActive ? "Session running on your Apple Watch" : "Start Dream Mode on Apple Watch, then monitor it here")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        isRemoteSessionActive ? Color(red: 0.99, green: 0.58, blue: 0.43) : Color(red: 0.25, green: 0.53, blue: 1.0),
                        isRemoteSessionActive ? Color(red: 0.88, green: 0.32, blue: 0.71) : Color(red: 0.63, green: 0.37, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
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
