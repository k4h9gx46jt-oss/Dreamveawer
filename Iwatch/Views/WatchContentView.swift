import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var connectivity: WatchSideConnectivityManager

    var body: some View {
        VStack(spacing: 12) {
            Text("DreamWeaver")
                .font(.headline)
            Text(workoutManager.isTracking ? "Tracking..." : "Ready")
                .foregroundStyle(.secondary)
            HeartRateSparkline(samples: workoutManager.samples)
                .frame(height: 60)
                .overlay(alignment: .topLeading) {
                    Text("Heart rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
            HStack {
                VStack(alignment: .leading) {
                    Label("\(Int(workoutManager.currentHeartRate)) bpm", systemImage: "heart.fill")
                    Label("\(Int(workoutManager.currentHRV)) ms", systemImage: "waveform.path")
                }
                Spacer()
            }
            .font(.caption)
            Text(elapsedString)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Button(action: toggle) {
                Text(workoutManager.isTracking ? "Stop" : "Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .tint(workoutManager.isTracking ? .red : .purple)
        }
        .padding()
        .onAppear {
            connectivity.sendConnectionState(workoutManager.isTracking ? .tracking : .ready)
        }
    }

    private func toggle() {
        if workoutManager.isTracking {
            workoutManager.stop()
        } else {
            workoutManager.start()
        }
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

private extension WatchContentView {
    var elapsedString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: workoutManager.elapsed) ?? "00:00:00"
    }
}
