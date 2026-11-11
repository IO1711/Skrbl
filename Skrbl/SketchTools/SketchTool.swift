import SwiftUI

enum SketchTool: String, CaseIterable, Identifiable {
    case brush
    case filler

    var id: String {
        rawValue
    }
}
