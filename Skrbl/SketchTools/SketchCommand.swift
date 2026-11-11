import Foundation

struct SketchCommand: Codable, Sendable {
    enum Action: String, Codable, Sendable {
        case beginStroke
        case continueStroke
        case appendPoints
        case finishStroke
        case fill
        case snapshot
    }

    let action: Action
    let point: SketchPoint?
    let points: [SketchPoint]?
    let color: SketchColor?
    let elements: [SketchElement]?
    let currentStroke: SketchStroke?

    private init(
        action: Action,
        point: SketchPoint?,
        color: SketchColor?,
        elements: [SketchElement]?,
        currentStroke: SketchStroke?,
        points: [SketchPoint]? = nil
    ) {
        self.action = action
        self.point = point
        self.points = points
        self.color = color
        self.elements = elements
        self.currentStroke = currentStroke
    }

    static func begin(
        at point: SketchPoint,
        color: SketchColor
    ) -> SketchCommand {
        SketchCommand(
            action: .beginStroke,
            point: point,
            color: color,
            elements: nil,
            currentStroke: nil
        )
    }

    static func continueStroke(at point: SketchPoint) -> SketchCommand {
        SketchCommand(
            action: .continueStroke,
            point: point,
            color: nil,
            elements: nil,
            currentStroke: nil
        )
    }

    static func append(_ points: [SketchPoint]) -> SketchCommand {
        SketchCommand(
            action: .appendPoints,
            point: nil,
            color: nil,
            elements: nil,
            currentStroke: nil,
            points: points
        )
    }

    static func finish(at point: SketchPoint) -> SketchCommand {
        SketchCommand(
            action: .finishStroke,
            point: point,
            color: nil,
            elements: nil,
            currentStroke: nil
        )
    }

    static func fill(
        at point: SketchPoint,
        color: SketchColor
    ) -> SketchCommand {
        SketchCommand(
            action: .fill,
            point: point,
            color: color,
            elements: nil,
            currentStroke: nil
        )
    }

    static func snapshot(
        elements: [SketchElement],
        currentStroke: SketchStroke?
    ) -> SketchCommand {
        SketchCommand(
            action: .snapshot,
            point: nil,
            color: nil,
            elements: elements,
            currentStroke: currentStroke
        )
    }

    func isValid(
        maximumElements: Int = SketchDrawingLimits.maximumElements,
        maximumPointsPerStroke: Int = SketchDrawingLimits.maximumPointsPerStroke
    ) -> Bool {
        let hasNoSnapshot = elements == nil && currentStroke == nil
        switch action {
        case .beginStroke, .fill:
            return point?.isValid == true && color != nil
                && points == nil && hasNoSnapshot
        case .continueStroke, .finishStroke:
            return point?.isValid == true && color == nil
                && points == nil && hasNoSnapshot
        case .appendPoints:
            return point == nil && color == nil && hasNoSnapshot
                && (points?.count ?? 0) > 0
                && (points?.count ?? 0) <= SketchDrawingLimits.maximumBatchPoints
                && points?.allSatisfy(\.isValid) == true
        case .snapshot:
            guard point == nil, color == nil, points == nil,
                  let elements,
                  elements.count + (currentStroke == nil ? 0 : 1) <= maximumElements else {
                return false
            }
            var totalPoints = 0
            for element in elements {
                switch element.kind {
                case .stroke:
                    guard element.fill == nil, let stroke = element.stroke,
                          !stroke.points.isEmpty,
                          stroke.points.count <= maximumPointsPerStroke,
                          stroke.points.allSatisfy(\.isValid) else {
                        return false
                    }
                    totalPoints += stroke.points.count
                case .fill:
                    guard element.stroke == nil,
                          element.fill?.point.isValid == true else {
                        return false
                    }
                }
                guard totalPoints <= SketchDrawingLimits.maximumTotalPoints else { return false }
            }
            if let currentStroke {
                return !currentStroke.points.isEmpty
                    && currentStroke.points.count <= maximumPointsPerStroke
                    && currentStroke.points.allSatisfy(\.isValid)
                    && totalPoints + currentStroke.points.count <= SketchDrawingLimits.maximumTotalPoints
            }
            return true
        }
    }
}
