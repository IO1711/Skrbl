import Foundation

struct SketchStroke: Codable, Equatable, Sendable {
    var points: [SketchPoint]
    let color: SketchColor
}
