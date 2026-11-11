import Foundation

struct SketchElement: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case stroke
        case fill
    }

    let kind: Kind
    let stroke: SketchStroke?
    let fill: SketchFill?

    static func stroke(_ stroke: SketchStroke) -> SketchElement {
        SketchElement(kind: .stroke, stroke: stroke, fill: nil)
    }

    static func fill(_ fill: SketchFill) -> SketchElement {
        SketchElement(kind: .fill, stroke: nil, fill: fill)
    }
}
