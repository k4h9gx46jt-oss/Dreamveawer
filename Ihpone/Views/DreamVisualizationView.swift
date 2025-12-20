import SwiftUI

struct DreamVisualizationView: View {
    let dream: SleepData
    @StateObject private var engine = ParticleEngine()

    var body: some View {
        ZStack {
            LinearGradient(colors: dream.mood.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                for particle in engine.particles {
                    var resolved = context.resolve(Symbol(shape: Circle().path(in: CGRect(x: -particle.size/2, y: -particle.size/2, width: particle.size, height: particle.size)).path(in: .zero)))
                    resolved.shading = .color(Color(hue: particle.hue, saturation: 0.8, brightness: 1.0, opacity: 0.6))
                    context.draw(resolved, at: CGPoint(x: particle.position.x, y: particle.position.y))
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
