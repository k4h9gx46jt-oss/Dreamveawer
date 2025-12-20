import SwiftUI
import Charts

struct DreamDetailView: View {
    let dream: SleepData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DreamVisualizationView(dream: dream)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 30))

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
