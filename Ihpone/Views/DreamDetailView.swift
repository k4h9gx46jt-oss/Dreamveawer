import SwiftUI
import Charts

struct DreamDetailView: View {
    let dream: SleepData
    @State private var isGeneratingVideo = false
    @State private var videoResult: DreamVideoResult?
    @State private var videoError: String?
    @State private var mediaStatus: DreamMediaComposer.Status = .idle
    @State private var mediaProgress: Double = 0
    @State private var selectedDetailChart = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DreamVisualizationView(dream: dream)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 30))

                videoButton

                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Interpretation")
                        .font(.title2.bold())
                    Text(dream.aiNarrative)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    WrapTags(tags: dream.aiThemes)
                    WrapTags(tags: dream.aiSymbolism)
                    ProgressStack(title: "Intensity", value: dream.aiIntensity)
                    ProgressStack(title: "Lucidity", value: dream.aiConsciousness)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 16) {
                    Text("Heart Rate Timeline")
                        .font(.headline)
                    Chart(dream.biosignals) { point in
                        LineMark(x: .value("Time", point.timestamp), y: .value("Heart", point.heartRate))
                        AreaMark(x: .value("Time", point.timestamp), y: .value("Heart", point.heartRate))
                            .foregroundStyle(LinearGradient(colors: dream.mood.colors, startPoint: .top, endPoint: .bottom).opacity(0.4))
                    }
                    .frame(height: 200)
                    Text("Avg \(Int(dream.averageHeartRate)) bpm • REM \(Int(dream.remPercentage))% • Deep \(Int(dream.deepSleepPercentage))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                if !dream.biosignals.isEmpty {
                    dreamMetricCarousel
                }
            }
            .padding()
        }
        .background(LinearGradient(colors: [Color.black.opacity(0.9), Color(hex: 0x20124E)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: dream.aiNarrative) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $videoResult) { result in
            DreamVideoView(result: result)
        }
        .alert("Unable to create video", isPresented: .init(get: { videoError != nil }, set: { _ in videoError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(videoError ?? "")
        }
    }
}

private struct WrapTags: View {
    let tags: [String]

    var body: some View {
        FlexibleView(data: tags) { tag in
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

private extension DreamDetailView {
    var videoButton: some View {
        Button(action: generateVideo) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: dream.mood.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image(systemName: isGeneratingVideo ? "hourglass" : "play.circle")
                        .font(.title)
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, options: .repeating, value: isGeneratingVideo)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create AI Dream Video")
                        .font(.headline)
                    if isGeneratingVideo {
                        Text(mediaStatus.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProgressView(value: mediaProgress)
                            .tint(.white)
                    } else {
                        Text("Transform this dream into a short film")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(isGeneratingVideo)
    }

    var dreamMetricCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dream Biofeedback")
                .font(.headline)
            Text("Compare how your vitals moved through the night")
                .font(.caption)
                .foregroundStyle(.secondary)
            TabView(selection: $selectedDetailChart) {
                MultiMetricChart(
                    title: "Circulation",
                    subtitle: "Heart & HRV",
                    samples: dream.biosignals,
                    metrics: [
                        .init(label: "Heart", keyPath: \.heartRate, color: .pink),
                        .init(label: "HRV", keyPath: \.hrv, color: .blue)
                    ],
                    chartHeight: 220
                )
                .tag(0)

                MultiMetricChart(
                    title: "Respiration",
                    subtitle: "SpO₂ & Rate",
                    samples: dream.biosignals,
                    metrics: [
                        .init(label: "SpO₂", keyPath: \.spo2, color: .teal),
                        .init(label: "Resp Rate", keyPath: \.respiratoryRate, color: .green)
                    ],
                    chartHeight: 220
                )
                .tag(1)

                MultiMetricChart(
                    title: "Calm vs Risk",
                    subtitle: "Resp Rhythm & Apnea",
                    samples: dream.biosignals,
                    metrics: [
                        .init(label: "Resp Rhythm", keyPath: \.respiratoryRate, color: .mint),
                        .init(label: "Apnea Risk (×40)", color: .orange) { sample in
                            sample.apneaRisk * 40
                        }
                    ],
                    chartHeight: 220
                )
                .tag(2)

                MultiMetricChart(
                    title: "Environment",
                    subtitle: "Temp & Noise",
                    samples: dream.biosignals,
                    metrics: [
                        .init(label: "Temp", keyPath: \.wristTemperatureDelta, color: .purple),
                        .init(label: "Noise", keyPath: \.noiseExposure, color: .yellow)
                    ],
                    chartHeight: 220
                )
                .tag(3)
            }
            .frame(height: 300)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index == selectedDetailChart ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: index == selectedDetailChart ? 10 : 8, height: index == selectedDetailChart ? 10 : 8)
                        .animation(.easeInOut(duration: 0.2), value: selectedDetailChart)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    func generateVideo() {
        guard !isGeneratingVideo else { return }
        isGeneratingVideo = true
        mediaStatus = .preparing
        mediaProgress = 0.1
        videoError = nil

        Task {
            do {
                let result = try await DreamMediaComposer.shared.composeMedia(for: dream) { progress in
                    Task { @MainActor in
                        mediaStatus = .rendering
                        mediaProgress = progress
                    }
                }
                await MainActor.run {
                    videoResult = result
                    isGeneratingVideo = false
                    mediaStatus = .completed
                    mediaProgress = 1.0
                }
            } catch {
                await MainActor.run {
                    videoError = error.localizedDescription
                    isGeneratingVideo = false
                    mediaStatus = .failed
                }
            }
        }
    }
}

struct ProgressStack: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value * 100))%")
            }
            ProgressView(value: value)
                .tint(.white)
        }
    }
}
