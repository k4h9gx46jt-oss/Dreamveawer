import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var connectivity: WatchSideConnectivityManager

    var body: some View {
        ZStack {
            AngularGradient(colors: [.black, .indigo.opacity(0.7), .black], center: .center)
                .ignoresSafeArea()
            Group {
                if workoutManager.isTracking {
                    trackingPager
                } else {
                    idleScreen
                }
            }
            .padding()
        }
        .onAppear {
            workoutManager.refreshElapsed()
            broadcastCurrentState()
            connectivity.requestStatusSnapshot { snapshot in
                if snapshot.isTracking,
                   let sessionId = snapshot.sessionId,
                   let startDate = snapshot.startDate {
                    workoutManager.resumeIfNeeded(sessionId: sessionId, startDate: startDate)
                } else if workoutManager.isTracking {
                    workoutManager.handleRemoteStopSync()
                }
            }
        }
        .onChange(of: workoutManager.isTracking) { _, tracking in
            broadcastCurrentState()
            if tracking { workoutManager.refreshElapsed() }
        }
        .onChange(of: workoutManager.sessionStartDate) { _, _ in
            workoutManager.refreshElapsed()
        }
    }

    private var idleScreen: some View {
        ScrollView {
            overviewStack
        }
    }

    private var trackingPager: some View {
        TabView {
            ScrollView {
                overviewStack
            }
            .tag(0)

            ScrollView {
                dreamDetailStack
            }
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }

    private var overviewStack: some View {
        VStack(spacing: 12) {
            Text("DreamWeaver")
                .font(.headline)
                .foregroundStyle(.white)

            connectionBadge

            elapsedLabel

            Text(workoutManager.isTracking ? "Live connection ready" : "Tap start to launch Dream Mode")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            metricsRow

            MetricSparkline(
                title: "HRV trend",
                caption: "@sleepingchart",
                samples: workoutManager.samples,
                keyPath: \.hrv
            )

            if workoutManager.isTracking {
                remPhaseRow
            }

            actionButton
        }
    }

    private var dreamDetailStack: some View {
        VStack(spacing: 16) {
            dreamMirrorCard

            MetricSparkline(
                title: "HRV timeline",
                caption: "Streaming to iPhone",
                samples: workoutManager.samples,
                keyPath: \.hrv,
                chartHeight: 110
            )

            if workoutManager.isTracking {
                remPhaseRow
            }

            metricsRow

            actionButton
        }
    }

    private var dreamMirrorCard: some View {
        VStack(spacing: 8) {
            Label("Dream Session", systemImage: "wave.3.right")
                .font(.caption.bold())
                .foregroundStyle(.white)

            elapsedLabel

            Text("Live HR • HRV • REM")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var elapsedLabel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formattedElapsed(currentElapsed(reference: context.date)))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
        }
    }

    private var connectionBadge: some View {
        Label(workoutManager.isTracking ? "Dream Mode On" : "Ready to Start",
              systemImage: workoutManager.isTracking ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
            .font(.caption.bold())
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(workoutManager.isTracking ? Color.green.opacity(0.25) : Color.orange.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricCard(title: "Heart", value: "\(Int(workoutManager.currentHeartRate)) bpm", icon: "heart.fill", tint: .pink)
            metricCard(title: "HRV", value: "\(Int(workoutManager.currentHRV)) ms", icon: "waveform.path.ecg", tint: .cyan)
        }
    }

    private func metricCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(value, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var remPhaseRow: some View {
        HStack {
            Label(workoutManager.currentREMState.label, systemImage: "moon.zzz")
                .foregroundStyle(workoutManager.currentREMState.tint)
            Spacer()
            Text(workoutManager.currentREMState.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionButton: some View {
        Button(role: workoutManager.isTracking ? .destructive : nil, action: workoutManager.isTracking ? stopSession : startSession) {
            Text(workoutManager.isTracking ? "Stop Sleep" : "Start Dream Mode")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .tint(workoutManager.isTracking ? .red : .purple)
    }

    private func startSession() {
        workoutManager.start()
        connectivity.sendConnectionState(.tracking)
    }

    private func stopSession() {
        workoutManager.stop()
        connectivity.sendConnectionState(.ready)
    }

    private func broadcastCurrentState() {
        connectivity.sendConnectionState(workoutManager.isTracking ? .tracking : .ready)
    }

    private func currentElapsed(reference date: Date = Date()) -> TimeInterval {
        if workoutManager.isTracking, let start = workoutManager.sessionStartDate {
            return max(0, date.timeIntervalSince(start))
        }
        return workoutManager.elapsed
    }
}

private struct MetricSparkline: View {
    let title: String
    let caption: String
    let samples: [WatchSleepSample]
    let keyPath: KeyPath<WatchSleepSample, Double>
    let chartHeight: CGFloat

    init(title: String,
         caption: String,
         samples: [WatchSleepSample],
         keyPath: KeyPath<WatchSleepSample, Double>,
         chartHeight: CGFloat = 70) {
        self.title = title
        self.caption = caption
        self.samples = samples
        self.keyPath = keyPath
        self.chartHeight = chartHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                let points = normalizedPoints(width: proxy.size.width, height: proxy.size.height)
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    if points.count > 1 {
                        Path { path in
                            path.move(to: points.first ?? .zero)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    } else {
                        Text("Waiting for samples")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: chartHeight)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let slice = samples.suffix(60)
        let values = slice.map { $0[keyPath: keyPath] }
        guard let minValue = values.min(), let maxValue = values.max(), slice.count > 1 else {
            return []
        }
        let range = max(maxValue - minValue, 1)
        return slice.enumerated().map { index, sample in
            let x = CGFloat(index) / CGFloat(max(slice.count - 1, 1)) * width
            let normalized = (sample[keyPath: keyPath] - minValue) / range
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
