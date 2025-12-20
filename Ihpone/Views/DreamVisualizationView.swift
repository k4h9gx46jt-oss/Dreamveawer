import SwiftUI

struct DreamVisualizationView: View {
    let dream: SleepData
    @StateObject private var engine = ParticleEngine()

    var body: some View {
        ZStack {
            LinearGradient(colors: dream.mood.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            Canvas { context, _ in
                for particle in engine.particles {
                    let rect = CGRect(
                        x: particle.position.x - particle.size / 2,
                        y: particle.position.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    var path = Path()
                    path.addEllipse(in: rect)
                    context.fill(
                        path,
                        with: .color(Color(hue: particle.hue, saturation: 0.75, brightness: 1.0, opacity: 0.55))
                    )
                }
            }
            .blendMode(.screen)

            VStack(spacing: 12) {
                Text(dream.mood.displayName)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text(dream.aiNarrative)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                HStack {
                    ForEach(dream.aiSymbolism, id: \.self) { symbol in
                        Text(symbol)
                            .font(.largeTitle)
                    }
                }
            }
            .padding()
        }
    }
}
