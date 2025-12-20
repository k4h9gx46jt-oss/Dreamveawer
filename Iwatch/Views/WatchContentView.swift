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
    }

    private func toggle() {
        if workoutManager.isTracking {
            workoutManager.stop()
        } else {
            workoutManager.start()
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
