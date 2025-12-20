import SwiftUI

enum DreamMood: String, CaseIterable, Identifiable, Codable {
    case peaceful
    case calm
    case intense
    case turbulent
    case chaotic
    case ethereal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .peaceful: return "Peaceful"
        case .calm: return "Calm"
        case .intense: return "Intense"
        case .turbulent: return "Turbulent"
        case .chaotic: return "Chaotic"
        case .ethereal: return "Ethereal"
        }
    }

    var colors: [Color] {
        switch self {
        case .peaceful:
            return [Color(hex: 0x8EC5FC), Color(hex: 0xE0C3FC)]
        case .calm:
            return [Color(hex: 0x6DD5ED), Color(hex: 0x2193B0)]
        case .intense:
            return [Color(hex: 0xFF512F), Color(hex: 0xDD2476)]
        case .turbulent:
            return [Color(hex: 0xF83600), Color(hex: 0xF9D423)]
        case .chaotic:
            return [Color(hex: 0x41295A), Color(hex: 0x2F0743)]
        case .ethereal:
            return [Color(hex: 0xC33764), Color(hex: 0x1D2671)]
        }
    }

    var icon: String {
        switch self {
        case .peaceful: return "leaf.fill"
        case .calm: return "water.waves"
        case .intense: return "flame.fill"
        case .turbulent: return "wind"
        case .chaotic: return "tornado"
        case .ethereal: return "sparkles"
        }
    }
}

extension Color {
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
