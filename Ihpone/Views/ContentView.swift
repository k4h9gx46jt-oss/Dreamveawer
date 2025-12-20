import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataStore: SleepDataStore
    @State private var showingTracking = false
    @State private var selectedDream: SleepData?

    var body: some View {
        NavigationSplitView {
            DreamDashboardView(
                lastDream: dataStore.dreams.first,
                history: dataStore.dreams,
                startTapped: { showingTracking = true },
                dreamTapped: { dream in selectedDream = dream }
            )
            .navigationTitle("DreamWeaver")
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
