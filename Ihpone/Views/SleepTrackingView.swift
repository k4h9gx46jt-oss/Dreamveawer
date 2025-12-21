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
    @State private var mediaStatus: DreamMediaComposer.Status = .idle
    @State private var mediaProgress: Double = 0
    @State private var mediaError: String?
    @State private var dreamVideoResult: DreamVideoResult?

    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                connectionStatusCard

                biosignalMetricGrid

                sleepingCharts

                if isProcessingAI {
                    renderStatusBanner
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
            .padding(.vertical, 24)
            .padding(.horizontal)
        }
        .sheet(item: $dreamVideoResult) { result in
            DreamVideoView(result: result)
        }
        .alert("Dream media unavailable", isPresented: .init(get: { mediaError != nil }, set: { _ in mediaError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mediaError ?? "")
        }
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

    private func metricCard(title: String, value: String, detail: String? = nil, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
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
        completedSession.analyzeREMProfile()
        Task {
            await MainActor.run {
                isProcessingAI = true
                mediaStatus = .preparing
                mediaProgress = 0.05
            }
            if let dream = await dataStore.persistSession(completedSession) {
                await produceDreamMedia(for: dream)
            } else {
                await MainActor.run {
                    isProcessingAI = false
                    mediaStatus = .failed
                    mediaError = "AI analysis was not available."
                }
            }
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

    var renderStatusBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProgressView(value: mediaProgress)
                    .tint(.white)
                Text(mediaStatus.label)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text(mediaStatus.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    var biosignalMetricGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 16) {
            metricCard(title: "Heart", value: formattedMetric(connectivity.liveHeartRate, suffix: " bpm"), detail: hrAlertText, icon: "heart.fill", color: .pink)
            metricCard(title: "HRV", value: formattedMetric(connectivity.liveHRV, suffix: " ms"), detail: hrvStatusText, icon: "waveform.path", color: .blue)
            metricCard(title: "SpO2", value: formattedMetric(connectivity.liveSpO2, suffix: "%"), detail: respiratoryStatusText, icon: "lungs.fill", color: .teal)
            metricCard(title: "Resp. Rate", value: formattedMetric(connectivity.liveRespiratoryRate, suffix: " brpm"), detail: apneaStatusText, icon: "wind", color: .cyan)
            metricCard(title: "ECG", value: formattedMetric(connectivity.liveECGConfidence * 100, suffix: "%"), detail: ecgStatusText, icon: "bolt.heart", color: .orange)
            metricCard(title: "Hypertension", value: formattedMetric(connectivity.liveHypertensionRisk * 100, suffix: "%"), detail: hypertensionStatusText, icon: "cross.case.fill", color: .red)
            metricCard(title: "Wrist Temp", value: String(format: "%+.1f degC", connectivity.liveTemperatureDelta), detail: temperatureStatusText, icon: "thermometer", color: .purple)
            metricCard(title: "Sleep Stage", value: connectivity.liveSleepStage, detail: sleepStageDetailText, icon: "moon.zzz", color: .indigo)
            metricCard(title: "Sleep Score", value: formattedMetric(connectivity.liveSleepScore, suffix: ""), detail: sleepScoreStatusText, icon: "sparkles", color: .mint)
            metricCard(title: "Noise", value: formattedMetric(connectivity.liveNoiseExposure, suffix: " dBA"), detail: noiseStatusText, icon: "ear", color: .yellow)
        }
    }

    var sleepingCharts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("@sleepingchart")
                .font(.headline)
            TabView {
                LiveMetricChart(
                    title: "Circulatory",
                    subtitle: "Heart & HRV",
                    samples: connectivity.sleepSamples,
                    metrics: [
                        .init(label: "Heart", keyPath: \.heartRate, color: .pink),
                        .init(label: "HRV", keyPath: \.hrv, color: .blue)
                    ]
                )
                LiveMetricChart(
                    title: "Respiratory",
                    subtitle: "SpO2 & Rate",
                    samples: connectivity.sleepSamples,
                    metrics: [
                        .init(label: "SpO2", keyPath: \.spo2, color: .teal),
                        .init(label: "Resp Rate", keyPath: \.respiratoryRate, color: .green)
                    ]
                )
                LiveMetricChart(
                    title: "Thermoreg & Noise",
                    subtitle: "Temp & Sound",
                    samples: connectivity.sleepSamples,
                    metrics: [
                        .init(label: "Temp", keyPath: \.wristTemperatureDelta, color: .purple),
                        .init(label: "Noise", keyPath: \.noiseExposure, color: .yellow)
                    ]
                )
            }
            .frame(height: 220)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func formattedMetric(_ value: Double, suffix: String, placeholder: String = "--") -> String {
        guard value != 0 else { return placeholder }
        let integer = suffix.contains("%") ? Int(value.rounded()) : Int(value.rounded())
        return "\(integer)\(suffix)"
    }

    private var hrAlertText: String {
        guard connectivity.liveHeartRate > 0 else { return "Waiting for data" }
        if connectivity.liveHeartRate > 90 { return "Elevated circulation" }
        if connectivity.liveHeartRate < 50 { return "Calm flow" }
        return "Steady"
    }

    private var hrvStatusText: String {
        guard connectivity.liveHRV > 0 else { return "Awaiting signal" }
        return connectivity.liveHRV > 40 ? "Recovered" : "Recharge soon"
    }

    private var respiratoryStatusText: String {
        guard connectivity.liveSpO2 > 0 else { return "Waiting" }
        return connectivity.liveSpO2 >= 95 ? "Optimal oxygen" : "Boost breathing"
    }

    private var apneaStatusText: String {
        guard connectivity.liveRespiratoryRate > 0 else { return "Waiting" }
        return connectivity.liveApneaRisk < 0.4 ? "Low risk" : "Monitor closely"
    }

    private var ecgStatusText: String {
        guard connectivity.liveECGConfidence > 0 else { return "Waiting" }
        return connectivity.liveECGConfidence > 0.85 ? "Stable rhythm" : "Hold steady"
    }

    private var hypertensionStatusText: String {
        guard connectivity.liveHypertensionRisk > 0 else { return "Baseline" }
        if connectivity.liveHypertensionRisk > 0.7 { return "High" }
        if connectivity.liveHypertensionRisk > 0.4 { return "Watch" }
        return "Controlled"
    }

    private var temperatureStatusText: String {
        abs(connectivity.liveTemperatureDelta) < 0.5 ? "Stable" : "Shift detected"
    }

    private var sleepStageDetailText: String {
        switch connectivity.liveSleepStage {
        case "REM": return "Dream intense"
        case "Deep": return "Restoring"
        case "Idle": return "Session paused"
        default: return "Light drift"
        }
    }

    private var sleepScoreStatusText: String {
        guard connectivity.liveSleepScore > 0 else { return "Calibrating" }
        if connectivity.liveSleepScore >= 85 { return "Excellent" }
        if connectivity.liveSleepScore >= 70 { return "On track" }
        return "Needs recovery"
    }

    private var noiseStatusText: String {
        guard connectivity.liveNoiseExposure > 0 else { return "Measuring" }
        return connectivity.liveNoiseExposure < 40 ? "Calm" : "Noisy"
    }
}

private extension SleepTrackingView {
    func produceDreamMedia(for dream: SleepData) async {
        do {
            let result = try await DreamMediaComposer.shared.composeMedia(for: dream) { value in
                Task { @MainActor in
                    mediaStatus = .rendering
                    mediaProgress = value
                }
            }
            await MainActor.run {
                dreamVideoResult = result
                isProcessingAI = false
                mediaStatus = .completed
                mediaProgress = 1.0
            }
        } catch {
            await MainActor.run {
                mediaError = error.localizedDescription
                isProcessingAI = false
                mediaStatus = .failed
            }
        }
    }
}

private struct LiveMetricChart: View {
    struct MetricCurve {
        let label: String
        let keyPath: KeyPath<BiosignalDataPoint, Double>
        let color: Color
    }

    let title: String
    let subtitle: String
    let samples: [BiosignalDataPoint]
    let metrics: [MetricCurve]

    private var plotSamples: [BiosignalDataPoint] {
        Array(samples.suffix(160))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            if plotSamples.isEmpty {
                Text("Waiting for live data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                Chart {
                    ForEach(metrics, id: \.label) { metric in
                        ForEach(plotSamples) { sample in
                            LineMark(
                                x: .value("Time", sample.timestamp),
                                y: .value(metric.label, sample[keyPath: metric.keyPath])
                            )
                            .foregroundStyle(metric.color)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }
}
