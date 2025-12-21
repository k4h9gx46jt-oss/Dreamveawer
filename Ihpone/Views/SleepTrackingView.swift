import SwiftUI
import Charts

struct SleepTrackingView: View {
    @EnvironmentObject private var dataStore: SleepDataStore
    @EnvironmentObject private var connectivity: PhoneWatchConnectivityManager
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isTracking = false
    @State private var isProcessingAI = false
    @State private var session = SleepSession()
    @State private var aiResult: SleepAIResult?
    @State private var remoteControlled = false
    @State private var showingConnectionHelp = false

    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        VStack(spacing: 24) {
            connectionStatusCard

            HStack(spacing: 20) {
                metricCard(title: "Heart", value: "\(Int(connectivity.liveHeartRate)) bpm", icon: "heart.fill", color: .pink)
                metricCard(title: "HRV", value: "\(Int(connectivity.liveHRV)) ms", icon: "waveform.path", color: .blue)
            }

            sleepChart

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
        .onAppear {
            if !isTracking, let start = connectivity.remoteSessionStart {
                startTracking(triggeredByRemote: true, startDate: start)
            }
            connectivity.requestWatchStatusSnapshot(force: true)
        }
        .onDisappear { timer?.invalidate() }
        .onReceive(connectivity.$sleepSamples) { samples in
            guard isTracking else { return }
            session.biosignals = samples
            session.recalculateAverages()
        }
        .onReceive(connectivity.$remoteSessionStart) { start in
            guard let start else { return }
            if !isTracking {
                startTracking(triggeredByRemote: true, startDate: start)
            }
        }
        .onReceive(connectivity.$remoteSessionEndedAt) { end in
            guard let end, isTracking, remoteControlled else { return }
            stopTracking(triggeredByRemote: true, endDate: end)
        }
        .confirmationDialog("Apple Watch Connection", isPresented: $showingConnectionHelp, titleVisibility: .visible) {
            Button("Retry Connection") {
                connectivity.attemptReconnect()
            }
            Button("Open Watch App") {
                connectivity.openWatchAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Make sure your Apple Watch is nearby, unlocked, and the DreamWeaver watch app is installed.")
        }
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

    private func startTracking(triggeredByRemote: Bool = false, startDate: Date = Date()) {
        guard !isTracking else { return }
        isTracking = true
        remoteControlled = triggeredByRemote
        session = SleepSession(startedAt: startDate)
        elapsed = Date().timeIntervalSince(startDate)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed = Date().timeIntervalSince(session.startedAt)
        }
        connectivity.startMirroringLiveData()
        if !triggeredByRemote {
            connectivity.startSleepSession(id: session.id)
        }
    }

    private func stopTracking(triggeredByRemote: Bool = false, endDate: Date = Date()) {
        guard isTracking else { return }
        isTracking = false
        remoteControlled = false
        timer?.invalidate()
        timer = nil
        let samples = connectivity.sleepSamples
        if !triggeredByRemote {
            connectivity.stopMirroringLiveData()
            connectivity.stopSleepSession(id: session.id)
        }
        var completedSession = session
        completedSession.biosignals = samples
        completedSession.recalculateAverages()
        completedSession.finish(on: endDate)
        Task {
            await MainActor.run { isProcessingAI = true }
            await dataStore.persistSession(completedSession)
            await MainActor.run { isProcessingAI = false }
        }
    }
}

private extension SleepTrackingView {
    var connectionStatusCard: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.ultraThinMaterial)
            .overlay(
                VStack(spacing: 12) {
                    Label(connectivity.isWatchReachable ? "⌚ Watch Connected" : "⌚ Watch Unavailable", systemImage: connectivity.isWatchReachable ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(connectivity.isWatchReachable ? .green : .orange)
                        .animation(.easeInOut, value: connectivity.isWatchReachable)
                    Text(formatter.string(from: elapsed) ?? "00:00:00")
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                    Text(connectivity.isWatchReachable ? "Live connection ready" : "Tap to test the connection or open the Watch app to finish setup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                    .padding()
            )
            .frame(height: 190)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !connectivity.isWatchReachable else { return }
                connectivity.attemptReconnect()
                showingConnectionHelp = true
            }
    }

    var sleepChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("@sleepingchart")
                .font(.headline)
            Chart {
                ForEach(connectivity.remWindows) { window in
                    RectangleMark(xStart: .value("Start", window.start), xEnd: .value("End", window.end), yStart: .value("REM", 40), yEnd: .value("REM", 120))
                        .foregroundStyle(.purple.opacity(0.2))
                }
                ForEach(connectivity.sleepSamples) { sample in
                    LineMark(x: .value("Time", sample.timestamp), y: .value("Heart", sample.heartRate))
                        .foregroundStyle(.pink)
                }
            }
            .frame(height: 180)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
