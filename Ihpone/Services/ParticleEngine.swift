import Foundation
import SwiftUI

struct DreamParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat
    var hue: Double
}

@MainActor
final class ParticleEngine: ObservableObject {
    @Published var particles: [DreamParticle] = []
    private var displayLink: CADisplayLink?
    private let bounds: CGRect

    init(bounds: CGRect = CGRect(x: 0, y: 0, width: 320, height: 560)) {
        self.bounds = bounds
        self.particles = Self.generateParticles(in: bounds)
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc private func step() {
        particles = particles.map { particle in
            var next = particle
            let newX = particle.position.x + particle.velocity.dx * 0.6
            let newY = particle.position.y + particle.velocity.dy * 0.6
            let wrappedX = (newX < 0) ? bounds.width : (newX > bounds.width ? 0 : newX)
            let wrappedY = (newY < 0) ? bounds.height : (newY > bounds.height ? 0 : newY)
            next.position = CGPoint(x: wrappedX, y: wrappedY)
            return next
        }
    }

    private static func generateParticles(in rect: CGRect) -> [DreamParticle] {
        (0..<60).map { _ in
            DreamParticle(
                position: CGPoint(x: Double.random(in: 0...rect.width), y: Double.random(in: 0...rect.height)),
                velocity: CGVector(dx: Double.random(in: -0.8...0.8), dy: Double.random(in: -0.8...0.8)),
                size: CGFloat.random(in: 2...7),
                hue: Double.random(in: 0...1)
            )
        }
    }
}
