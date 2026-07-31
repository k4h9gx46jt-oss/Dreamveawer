import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataStore: SleepDataStore
    @EnvironmentObject private var connectivity: PhoneWatchConnectivityManager
    @State private var showingTracking = false
    @State private var selectedDream: SleepData?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                watchStatusBanner
                DreamDashboardView(
                    lastDream: dataStore.dreams.first,
                    history: dataStore.dreams,
                    startTapped: {
                        showingTracking = true
                    },
                    dreamTapped: { dream in selectedDream = dream },
                    isRemoteSessionActive: connectivity.hasAnyActiveSession
                )
            }
            .padding(.top, 8)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingTracking) {
                SleepTrackingView()
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedDream) { dream in
                DreamDetailView(dream: dream)
            }
        } detail: {
            ZStack {
                LinearGradient(colors: [Color.black, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("See What Your Mind Creates")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }

            }
        }
    }
}

private extension ContentView {
    var watchStatusBanner: some View {
        let connected = connectivity.isWatchReachable
        let iconName = connected ? "dot.radiowaves.left.and.right" : "applewatch.slash"
        let statusText = connected ? "Apple Watch Connected" : "Waiting for Apple Watch"
        let detailText = connected ? "Live dream metrics streaming" : "Open DreamWeaver on your watch to sync"

        return HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(connected ? .green : .orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detailText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(connected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Watch connection status")
        .accessibilityValue(statusText)
        .padding(.horizontal)
    }
}
