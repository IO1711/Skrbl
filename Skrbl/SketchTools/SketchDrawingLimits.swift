nonisolated enum SketchDrawingLimits {
    static let maximumElements = 1_000
    static let maximumPointsPerStroke = 4_096
    // Keeps an encoded snapshot below the wire packet limit, including element metadata.
    static let maximumTotalPoints = 12_000
    static let maximumBatchPoints = 64
}
