import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var connectivity: WatchSideConnectivityManager
    @State private var showLiveMonitor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    HeartRateSparkline(samples: workoutManager.samples)
                        .frame(height: 60)
                        .overlay(alignment: .topLeading) {
                            Text("Heart rate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(4)
                        }
                    metricOverview
                    Text(formattedElapsed(workoutManager.elapsed))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Button(action: handlePrimaryAction) {
                        Text(workoutManager.isTracking ? "Stop Sleep" : "Start Dream Mode")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(workoutManager.isTracking ? .red : .purple)
                    if workoutManager.isTracking {
                        Button {
                            showLiveMonitor = true
                        } label: {
                            Text("Live HR Monitor")
                                .font(.callout)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationDestination(isPresented: $showLiveMonitor) {
                LiveSleepSessionView(isPresented: $showLiveMonitor)
                    .environmentObject(workoutManager)
                    .environmentObject(connectivity)
            }
        }
        .onAppear {
            connectivity.sendConnectionState(workoutManager.isTracking ? .tracking : .ready)
            if workoutManager.isTracking {
                showLiveMonitor = true
            }
        }
        .onChange(of: workoutManager.isTracking) { _, isTracking in
            showLiveMonitor = isTracking
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("DreamWeaver")
                .font(.headline)
            Text(workoutManager.isTracking ? "Session running" : "Ready")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricOverview: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("\(Int(workoutManager.currentHeartRate)) bpm", systemImage: "heart.fill")
                Label("\(Int(workoutManager.currentHRV)) ms", systemImage: "waveform.path")
            }
            Spacer()
        }
        .font(.caption)
    }

    private func handlePrimaryAction() {
        if workoutManager.isTracking {
            workoutManager.stop()
        } else {
            workoutManager.start()
            showLiveMonitor = true
        }
    }
}

struct LiveSleepSessionView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var connectivity: WatchSideConnectivityManager
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Live Sleep Monitor")
                    .font(.headline)
                Text("Session has started. Keep your Apple Watch snug for accurate readings.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                HeartRateSparkline(samples: workoutManager.samples)
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    metricRow(title: "Heart Rate", value: "\(Int(workoutManager.currentHeartRate)) bpm", icon: "heart.fill")
                    metricRow(title: "HRV", value: "\(Int(workoutManager.currentHRV)) ms", icon: "waveform.path")
                    metricRow(title: "Elapsed", value: formattedElapsed(workoutManager.elapsed), icon: "timer")
                    phaseRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                Button(action: stopSession) {
                    Text("Stop Sleep Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
                Button("Done") {
                    dismissView()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Live Session")
        .onAppear {
            if workoutManager.isTracking {
                connectivity.sendConnectionState(.tracking)
            }
        }
        .onChange(of: workoutManager.isTracking) { _, active in
            if !active {
                dismissView()
            }
        }
    }

    private var phaseRow: some View {
        HStack {
            Label(workoutManager.currentREMState.label, systemImage: "moon.zzz")
                .foregroundStyle(workoutManager.currentREMState.tint)
            Spacer()
            Text(workoutManager.currentREMState.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func metricRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Label(value, systemImage: icon)
            Spacer()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func stopSession() {
        guard workoutManager.isTracking else {
            dismissView()
            return
        }
        workoutManager.stop()
        connectivity.sendConnectionState(.ready)
        dismissView()
    }

    private func dismissView() {
        isPresented = false
        dismiss()
    }
}

private struct HeartRateSparkline: View {
    let samples: [WatchSleepSample]

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(width: proxy.size.width, height: proxy.size.height)
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                if points.count > 1 {
                    Path { path in
                        path.move(to: points.first ?? .zero)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard let minHR = samples.map({ $0.heartRate }).min(),
              let maxHR = samples.map({ $0.heartRate }).max(),
              maxHR != minHR else { return [] }
        let slice = samples.suffix(60)
        return slice.enumerated().map { index, sample in
            let x = CGFloat(index) / CGFloat(max(slice.count - 1, 1)) * width
            let normalized = (sample.heartRate - minHR) / (maxHR - minHR)
            let y = height - (CGFloat(normalized) * height)
            return CGPoint(x: x, y: y)
        }
    }
}

private let elapsedFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter
}()

private func formattedElapsed(_ interval: TimeInterval) -> String {
    elapsedFormatter.string(from: interval) ?? "00:00:00"
}

private extension REMState {
    var label: String {
        switch self {
        case .rem: return "REM phase"
        case .deep: return "Deep phase"
        case .light: return "Light phase"
        }
    }

    var detail: String {
        switch self {
        case .rem: return "Dream-heavy sleep"
        case .deep: return "Restoring energy"
        case .light: return "Transitioning"
        }
    }

    var tint: Color {
        switch self {
        case .rem: return .purple
        case .deep: return .blue
        case .light: return .teal
        }
    }
}
