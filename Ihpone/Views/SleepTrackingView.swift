import SwiftUI

struct SleepTrackingView: View {
    @EnvironmentObject private var dataStore: SleepDataStore
    @EnvironmentObject private var connectivity: PhoneWatchConnectivityManager
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isTracking = false
    @State private var isProcessingAI = false
    @State private var session = SleepSession()
    @State private var aiResult: SleepAIResult?

    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    VStack(spacing: 16) {
                        Label(connectivity.isWatchReachable ? "⌚ Watch Connected" : "⌚ Watch Unavailable", systemImage: connectivity.isWatchReachable ? "checkmark.circle.fill" : "exclamationmark.triangle")
                            .foregroundStyle(connectivity.isWatchReachable ? .green : .orange)
                        Text(formatter.string(from: elapsed) ?? "00:00:00")
                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                    }
                        .padding()
                )
                .frame(height: 170)

            HStack(spacing: 20) {
                metricCard(title: "Heart", value: "\(Int(connectivity.liveHeartRate)) bpm", icon: "heart.fill", color: .pink)
                metricCard(title: "HRV", value: "\(Int(connectivity.liveHRV)) ms", icon: "waveform.path", color: .blue)
            }

            if isProcessingAI {
                ProgressView("Interpreting your dream...")
                    .progressViewStyle(.circular)
            }

            Button(action: toggleTracking) {
                Text(isTracking ? "Stop Tracking" : "Start Dream Mode")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTracking ? Color.red : Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
            }
        }
        .padding()
        .onDisappear { timer?.invalidate() }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Spacer()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func toggleTracking() {
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }

    private func startTracking() {
        isTracking = true
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
        }
        session = SleepSession()
        connectivity.startMirroringLiveData()
        connectivity.startSleepSession(id: session.id)
    }

    private func stopTracking() {
        isTracking = false
        timer?.invalidate()
        timer = nil
        connectivity.stopMirroringLiveData()
        connectivity.stopSleepSession(id: session.id)
        session.finish()
        Task {
            isProcessingAI = true
            let result = try? await AIDreamService.shared.interpret(session: session)
            await MainActor.run {
                isProcessingAI = false
                if let result {
                    dataStore.addDream(from: session, aiResult: result)
                }
            }
        }
    }
}
