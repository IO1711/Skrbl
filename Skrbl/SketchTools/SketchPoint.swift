import CoreGraphics
import Foundation

struct SketchPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double

    init(location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            x = 0
            y = 0
            return
        }

        x = min(max(Double(location.x / size.width), 0), 1)
        y = min(max(Double(location.y / size.height), 0), 1)
    }

    func location(in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(x) * size.width,
            y: CGFloat(y) * size.height
        )
    }

    var isValid: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
    }
}
