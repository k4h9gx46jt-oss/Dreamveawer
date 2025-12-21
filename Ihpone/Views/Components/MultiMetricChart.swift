import SwiftUI
import Charts

/// Shared chart view that renders multiple biosignal metrics with consistent styling.
struct MultiMetricChart: View {
    struct MetricCurve: Hashable {
        let label: String
        let color: Color
        private let valueProvider: (BiosignalDataPoint) -> Double

        init(label: String, keyPath: KeyPath<BiosignalDataPoint, Double>, color: Color) {
            self.label = label
            self.color = color
            self.valueProvider = { $0[keyPath: keyPath] }
        }

        init(label: String, color: Color, valueProvider: @escaping (BiosignalDataPoint) -> Double) {
            self.label = label
            self.color = color
            self.valueProvider = valueProvider
        }

        func value(for point: BiosignalDataPoint) -> Double {
            valueProvider(point)
        }
    }

    let title: String
    let subtitle: String
    let samples: [BiosignalDataPoint]
    let metrics: [MetricCurve]
    var chartHeight: CGFloat = 200
    var sampleLimit: Int = 160

    private var plotSamples: [BiosignalDataPoint] {
        Array(samples.suffix(sampleLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                if plotSamples.isEmpty {
                    Text("Waiting for data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(metrics, id: \.label) { metric in
                            ForEach(plotSamples) { sample in
                                LineMark(
                                    x: .value("Time", sample.timestamp),
                                    y: .value(metric.label, metric.value(for: sample)),
                                    series: .value("Metric", metric.label)
                                )
                                // Explicit series keeps curves separate so no rogue connectors appear.
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
                    .chartLegend(.hidden)
                    .chartForegroundStyleScale(
                        domain: metrics.map { $0.label },
                        range: metrics.map { $0.color }
                    )
                    .padding(12)
                }
            }
            .frame(height: chartHeight)
            legend
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(metrics, id: \.label) { metric in
                HStack(spacing: 6) {
                    Circle()
                        .fill(metric.color)
                        .frame(width: 10, height: 10)
                    Text(metric.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
