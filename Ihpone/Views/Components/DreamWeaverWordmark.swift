import CoreText
import SwiftUI
import UIKit

/// Picks the most elegant calligraphic face available, preferring the bundled script font
/// so that iPhone and Watch render an identical wordmark.
enum DreamScript {
    /// Registering at runtime keeps the font working without an Info.plist UIAppFonts entry.
    private static let registeredBundledFont: Bool = {
        guard let url = Bundle.main.url(forResource: "GreatVibes-Regular", withExtension: "ttf"),
              let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider) else { return false }
        return CTFontManagerRegisterGraphicsFont(font, nil)
    }()

    private static let resolved: (name: String, scale: CGFloat)? = {
        _ = registeredBundledFont
        let candidates: [(String, CGFloat)] = [
            ("GreatVibes-Regular", 1.32),
            ("Tangerine-Bold", 1.55),
            ("Parisienne-Regular", 1.30),
            ("DancingScript-SemiBold", 1.16),
            ("SnellRoundhand-Black", 1.20),
            ("SnellRoundhand-Bold", 1.20),
            ("SnellRoundhand", 1.20),
            ("SavoyeLetPlain", 1.38),
            ("Zapfino", 0.60),
            ("Noteworthy-Bold", 0.96)
        ]
        guard let match = candidates.first(where: { UIFont(name: $0.0, size: 12) != nil }) else { return nil }
        return (name: match.0, scale: match.1)
    }()

    static func font(size: CGFloat) -> Font {
        guard let resolved else {
            return .system(size: size * 0.84, weight: .semibold, design: .serif).italic()
        }
        return .custom(resolved.name, size: size * resolved.scale)
    }
}

/// The DreamWeaver wordmark: calligraphic lettering with a gradient ink, a slow glint and a swash.
struct DreamWeaverWordmark: View {
    var size: CGFloat = 38
    var tint: [Color] = [
        Color(red: 0.16, green: 0.09, blue: 0.42),
        Color(red: 0.42, green: 0.18, blue: 0.72),
        Color(red: 0.72, green: 0.36, blue: 0.90),
        Color(red: 0.35, green: 0.20, blue: 0.68)
    ]
    var showsFlourish = true

    var body: some View {
        VStack(spacing: -size * 0.04) {
            lettering
            if showsFlourish {
                flourish
                    .frame(width: size * 5.0, height: size * 0.34)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("DreamWeaver")
    }
}

private extension DreamWeaverWordmark {
    var letters: some View {
        Text("DreamWeaver")
            .font(DreamScript.font(size: size))
            .kerning(size * 0.012)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
    }

    var lettering: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            letters
                .foregroundStyle(
                    LinearGradient(colors: tint, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay { glint(progress: glintProgress(at: elapsed)) }
                .shadow(color: tint[1].opacity(0.38), radius: size * 0.34, y: size * 0.06)
                .shadow(color: .white.opacity(0.55), radius: 1, y: -1)
        }
        .padding(.horizontal, size * 0.12)
    }

    /// A single highlight sweeps across roughly every seven seconds, then rests off-screen.
    func glintProgress(at elapsed: TimeInterval) -> Double {
        let cycle = elapsed.truncatingRemainder(dividingBy: 7) / 7
        return cycle < 0.3 ? cycle / 0.3 : 1.35
    }

    func glint(progress: Double) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(colors: [.clear, .white.opacity(0.85), .clear],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(width: width * 0.34)
                .offset(x: -width * 0.34 + CGFloat(progress) * width * 1.34)
        }
        .mask(letters)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    var flourish: some View {
        SwashCurve()
            .stroke(
                LinearGradient(colors: [.clear, tint[2].opacity(0.6), tint[1].opacity(0.7), .clear],
                               startPoint: .leading,
                               endPoint: .trailing),
                style: StrokeStyle(lineWidth: max(0.8, size * 0.03), lineCap: .round)
            )
    }
}

private struct SwashCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.26, y: rect.maxY * 1.1),
            control2: CGPoint(x: rect.width * 0.74, y: rect.minY - rect.height * 0.1)
        )
        return path
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [Color(red: 0.95, green: 0.88, blue: 1.0),
                                Color(red: 0.84, green: 0.72, blue: 1.0)],
                       startPoint: .top,
                       endPoint: .bottom)
            .ignoresSafeArea()
        DreamWeaverWordmark()
    }
}
