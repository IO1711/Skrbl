import Foundation

enum SketchColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case black
    case gray
    case red
    case orange
    case yellow
    case green
    case cyan
    case blue
    case purple
    case pink
    case brown
    case white

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue.capitalized
    }

    nonisolated var rgba: SketchRGBA {
        switch self {
        case .black:
            SketchRGBA(red: 0, green: 0, blue: 0, alpha: 255)
        case .gray:
            SketchRGBA(red: 128, green: 128, blue: 128, alpha: 255)
        case .red:
            SketchRGBA(red: 230, green: 52, blue: 64, alpha: 255)
        case .orange:
            SketchRGBA(red: 242, green: 133, blue: 0, alpha: 255)
        case .yellow:
            SketchRGBA(red: 245, green: 201, blue: 28, alpha: 255)
        case .green:
            SketchRGBA(red: 39, green: 174, blue: 96, alpha: 255)
        case .cyan:
            SketchRGBA(red: 0, green: 174, blue: 239, alpha: 255)
        case .blue:
            SketchRGBA(red: 33, green: 120, blue: 246, alpha: 255)
        case .purple:
            SketchRGBA(red: 155, green: 81, blue: 224, alpha: 255)
        case .pink:
            SketchRGBA(red: 235, green: 87, blue: 137, alpha: 255)
        case .brown:
            SketchRGBA(red: 132, green: 94, blue: 62, alpha: 255)
        case .white:
            SketchRGBA(red: 255, green: 255, blue: 255, alpha: 255)
        }
    }
}
