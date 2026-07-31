import CoreText
import SwiftUI
import UIKit

/// watchOS ships no script faces, so the bundled Great Vibes font is registered at runtime
/// to match the iPhone wordmark exactly.
enum DreamScript {
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
            ("SavoyeLetPlain", 1.38)
        ]
        guard let match = candidates.first(where: { UIFont(name: $0.0, size: 12) != nil }) else { return nil }
        return (name: match.0, scale: match.1)
    }()

    static func font(size: CGFloat) -> Font {
        guard let resolved else {
            return .system(size: size * 0.86, weight: .semibold, design: .serif).italic()
        }
        return .custom(resolved.name, size: size * resolved.scale)
    }
}

/// Compact calligraphic DreamWeaver wordmark for the watch face-sized layout.
struct DreamWeaverWordmark: View {
    var size: CGFloat = 22

    private let tint: [Color] = [
        Color(red: 0.98, green: 0.95, blue: 1.0),
        Color(red: 0.82, green: 0.72, blue: 1.0),
        Color(red: 0.62, green: 0.48, blue: 0.98)
    ]

    var body: some View {
        VStack(spacing: -size * 0.04) {
            Text("DreamWeaver")
                .font(DreamScript.font(size: size))
                .kerning(size * 0.012)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(
                    LinearGradient(colors: tint, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: tint[2].opacity(0.7), radius: size * 0.3)

            SwashCurve()
                .stroke(
                    LinearGradient(colors: [.clear, tint[1].opacity(0.6), .clear],
                                   startPoint: .leading,
                                   endPoint: .trailing),
                    style: StrokeStyle(lineWidth: max(0.7, size * 0.035), lineCap: .round)
                )
                .frame(height: size * 0.26)
                .padding(.horizontal, size * 0.4)
        }
        .accessibilityElement()
        .accessibilityLabel("DreamWeaver")
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
