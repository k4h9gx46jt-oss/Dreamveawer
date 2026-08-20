import SwiftUI

/// First-run flow. Explains the product, primes Health access in context, and
/// never blocks: the user can proceed even if they decline permission.
struct OnboardingView: View {
    @ObservedObject var healthAccess: HealthAccessModel
    let onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 3

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1A1037), Color(hex: 0x3A1E6E), Color(hex: 0x20124E)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                TabView(selection: $page) {
                    OnboardingPage(
                        icon: "moon.stars.fill",
                        title: "See What Your Mind Creates",
                        message: "DreamWeaver composes a short film and an original score from the night you just lived — entirely on your device, with no account and no cloud."
                    )
                    .tag(0)

                    OnboardingPage(
                        icon: "applewatch",
                        title: "Your watch does the listening",
                        message: "Wear your Apple Watch to bed. DreamWeaver reads heart rate, HRV, breathing and movement, then syncs the night to iPhone automatically."
                    )
                    .tag(1)

                    permissionPage
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: page)

                controls
            }
            .padding()
        }
        .task { await healthAccess.refresh() }
    }

    private var permissionPage: some View {
        OnboardingPage(
            icon: "heart.text.square.fill",
            title: "Private by design",
            message: "Grant Health access so DreamWeaver can turn your biosignals into art. Your dreams never leave your device."
        )
    }

    @ViewBuilder
    private var controls: some View {
        if page < pageCount - 1 {
            Button {
                withAnimation { page += 1 }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
        } else {
            VStack(spacing: 12) {
                Button {
                    Task {
                        await healthAccess.request()
                        onFinish()
                    }
                } label: {
                    Text("Allow Health Access")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .controlSize(.large)

                Button("Not now", action: onFinish)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}
