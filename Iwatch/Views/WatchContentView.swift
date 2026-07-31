import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var connectivity: WatchSideConnectivityManager
    private let phoneSyncTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

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
            synchronizeWithPhone()
        }
        .onChange(of: workoutManager.isTracking) { _, tracking in
            broadcastCurrentState()
            if tracking { workoutManager.refreshElapsed() }
        }
        .onChange(of: workoutManager.sessionStartDate) { _, _ in
            workoutManager.refreshElapsed()
        }
        .onReceive(phoneSyncTimer) { _ in
            synchronizeWithPhone()
        }
    }

    private func synchronizeWithPhone() {
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

            biosignalSuites

            MetricSparkline(
                title: "Heart rhythm",
                caption: "Circulatory focus",
                samples: workoutManager.samples,
                keyPath: \.heartRate
            )

            MetricSparkline(
                title: "HRV trend",
                caption: "@sleepingchart",
                samples: workoutManager.samples,
                keyPath: \.hrv
            )

            MetricSparkline(
                title: "SpO2 timeline",
                caption: "Respiratory stream",
                samples: workoutManager.samples,
                keyPath: \.spo2,
                chartHeight: 60
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

            biosignalSuites

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

    private var biosignalSuites: some View {
        VStack(spacing: 10) {
            biosignalSection(title: "Circulatory", metrics: circulatoryMetrics)
            biosignalSection(title: "Respiratory", metrics: respiratoryMetrics)
            biosignalSection(title: "Thermoreg & Sleep", metrics: thermoregMetrics)
            biosignalSection(title: "Wellness", metrics: wellnessMetrics)
        }
    }

    private func biosignalSection(title: String, metrics: [SuiteMetric]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(metrics) { metric in
                    biosignalTile(metric)
                }
            }
        }
    }

    private func biosignalTile(_ metric: SuiteMetric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(metric.value, systemImage: metric.icon)
                .font(.caption)
                .foregroundStyle(metric.tint)
            Text(metric.title)
                .font(.caption2)
                .foregroundStyle(.white)
            Text(metric.detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var circulatoryMetrics: [SuiteMetric] {
        [
            SuiteMetric(title: "Heart Rate", value: "\(Int(workoutManager.currentHeartRate)) bpm", detail: hrAlertDetail, icon: "heart.fill", tint: .pink),
            SuiteMetric(title: "HR Alerts", value: hrAlertLabel, detail: "Flow \(hrAlertDetail)", icon: "bell.badge.fill", tint: .orange),
            SuiteMetric(title: "ECG", value: "\(Int(workoutManager.currentECGConfidence * 100))%", detail: ecgStatusText, icon: "bolt.heart", tint: .yellow),
            SuiteMetric(title: "Hypertension", value: riskPercent(workoutManager.currentHypertensionRisk), detail: hypertensionStatusText, icon: "cross.case.fill", tint: .red)
        ]
    }

    private var respiratoryMetrics: [SuiteMetric] {
        [
            SuiteMetric(title: "SpO2", value: "\(Int(workoutManager.currentSpO2))%", detail: respiratoryStatusText, icon: "lungs.fill", tint: .teal),
            SuiteMetric(title: "Resp. Rate", value: "\(Int(workoutManager.currentRespiratoryRate)) brpm", detail: respiratoryTrendText, icon: "wind", tint: .cyan),
            SuiteMetric(title: "Sleep Apnea", value: riskLabel(for: workoutManager.currentApneaRisk), detail: apneaStatusText, icon: "zzz", tint: .blue)
        ]
    }

    private var thermoregMetrics: [SuiteMetric] {
        [
            SuiteMetric(title: "Wrist Temp", value: String(format: "%+.1f degC", workoutManager.currentTemperatureDelta), detail: temperatureStatusText, icon: "thermometer", tint: .purple),
            SuiteMetric(title: "Sleep Stage", value: workoutManager.currentREMState.label, detail: workoutManager.currentREMState.detail, icon: "moonphase.waxing.crescent", tint: .indigo),
            SuiteMetric(title: "Sleep Score", value: "\(Int(workoutManager.currentSleepScore))", detail: sleepScoreStatusText, icon: "sparkles", tint: .mint)
        ]
    }

    private var wellnessMetrics: [SuiteMetric] {
        [
            SuiteMetric(title: "HRV", value: "\(Int(workoutManager.currentHRV)) ms", detail: hrvStatusText, icon: "waveform.path.ecg", tint: .cyan),
            SuiteMetric(title: "Resp. Quality", value: respiratoryQualityValue, detail: respiratoryQualityDetail, icon: "lungs", tint: .green),
            SuiteMetric(title: "Noise", value: "\(Int(workoutManager.currentNoiseExposure)) dBA", detail: noiseStatusText, icon: "ear", tint: .yellow)
        ]
    }

    private func riskPercent(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }

    private func riskLabel(for value: Double) -> String {
        value < 0.33 ? "Low" : (value < 0.66 ? "Medium" : "High")
    }

    private var hrAlertLabel: String {
        if workoutManager.currentHeartRate > 95 { return "Elevated" }
        if workoutManager.currentHeartRate < 50 { return "Calm" }
        return "Steady"
    }

    private var hrAlertDetail: String {
        "\(Int(workoutManager.currentHeartRate)) bpm"
    }

    private var ecgStatusText: String {
        workoutManager.currentECGConfidence > 0.85 ? "Stable rhythm" : "Analyze signal"
    }

    private var hypertensionStatusText: String {
        let risk = workoutManager.currentHypertensionRisk
        if risk > 0.7 { return "High pressure" }
        if risk > 0.4 { return "Watch closely" }
        return "Good control"
    }

    private var respiratoryStatusText: String {
        workoutManager.currentSpO2 >= 95 ? "Optimal oxygen" : "Boost breathing"
    }

    private var respiratoryTrendText: String {
        if workoutManager.currentRespiratoryRate > 18 { return "Elevated cadence" }
        if workoutManager.currentRespiratoryRate < 12 { return "Deep breaths" }
        return "Balanced flow"
    }

    private var apneaStatusText: String {
        let label = riskLabel(for: workoutManager.currentApneaRisk)
        return "Risk \(label.lowercased())"
    }

    private var temperatureStatusText: String {
        abs(workoutManager.currentTemperatureDelta) < 0.5 ? "Stable" : "Shift detected"
    }

    private var sleepScoreStatusText: String {
        if workoutManager.currentSleepScore > 90 { return "Excellent" }
        if workoutManager.currentSleepScore > 75 { return "On track" }
        return "Recover"
    }

    private var hrvStatusText: String {
        workoutManager.currentHRV > 40 ? "Resilient" : "Recharge"
    }

    private var respiratoryQualityValue: String {
        let quality = max(0, min(100, Int((1 - workoutManager.currentApneaRisk) * 100)))
        return "\(quality)%"
    }

    private var respiratoryQualityDetail: String {
        workoutManager.currentApneaRisk < 0.4 ? "Smooth flow" : "Therapy ready"
    }

    private var noiseStatusText: String {
        workoutManager.currentNoiseExposure < 40 ? "Calm room" : "Noisy"
    }

    private struct SuiteMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let detail: String
        let icon: String
        let tint: Color
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
        let spread = max(maxValue - minValue, 0.001)
        let padding = max(spread * 0.3, 1)
        let low = minValue - padding
        let high = maxValue + padding
        let range = max(high - low, 1)
        return slice.enumerated().map { index, sample in
            let x = CGFloat(index) / CGFloat(max(slice.count - 1, 1)) * width
            let normalized = (sample[keyPath: keyPath] - low) / range
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
