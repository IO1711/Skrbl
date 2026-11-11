import Observation
import SwiftUI

@MainActor
@Observable
final class SketchTools {
    private(set) var elements: [SketchElement] = []
    private(set) var currentStroke: SketchStroke?
    private(set) var renderedImage: CGImage?
    private(set) var strokesAwaitingRender: [SketchStroke] = []
    var selectedTool: SketchTool = .brush
    var selectedColor: SketchColor = .black

    @ObservationIgnored var commandHandler: ((SketchCommand) -> Void)?

    private var history: [[SketchElement]] = []
    @ObservationIgnored private var pendingPoints: [SketchPoint] = []
    @ObservationIgnored private var transmissionTask: Task<Void, Never>?
    @ObservationIgnored private var lastSampleTime = ContinuousClock.now
    @ObservationIgnored private let renderService = SketchRenderService()
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var renderGeneration = 0

    private let maximumElements = SketchDrawingLimits.maximumElements
    private let maximumPointsPerStroke = SketchDrawingLimits.maximumPointsPerStroke

    private var totalPointCount: Int {
        elements.reduce(0) { $0 + ($1.stroke?.points.count ?? 0) }
            + (currentStroke?.points.count ?? 0)
    }

    var canClear: Bool {
        !elements.isEmpty || currentStroke != nil
    }

    var canUndo: Bool {
        !history.isEmpty
    }

    var snapshotCommand: SketchCommand {
        .snapshot(elements: elements, currentStroke: currentStroke)
    }

    func beginStroke(at point: SketchPoint) {
        guard point.isValid, elements.count < maximumElements,
              totalPointCount < SketchDrawingLimits.maximumTotalPoints - 1 else { return }
        discardPendingPoints()
        lastSampleTime = ContinuousClock.now
        applyBeginStroke(at: point, color: selectedColor)
        commandHandler?(.begin(at: point, color: selectedColor))
    }

    func continueStroke(at point: SketchPoint) {
        guard point.isValid, let lastPoint = currentStroke?.points.last,
              let count = currentStroke?.points.count,
              count < maximumPointsPerStroke - 1,
              totalPointCount < SketchDrawingLimits.maximumTotalPoints - 1 else { return }

        let now = ContinuousClock.now
        let dx = point.x - lastPoint.x
        let dy = point.y - lastPoint.y
        guard dx * dx + dy * dy >= 0.003 * 0.003,
              lastSampleTime.duration(to: now) >= .milliseconds(16) else {
            return
        }

        lastSampleTime = now
        applyContinueStroke(at: point)
        pendingPoints.append(point)
        if pendingPoints.count >= SketchDrawingLimits.maximumBatchPoints {
            flushPendingPoints()
        } else {
            scheduleTransmission()
        }
    }

    func finishStroke(at point: SketchPoint) {
        guard point.isValid, currentStroke != nil else { return }

        flushPendingPoints()
        applyFinishStroke(at: point)
        commandHandler?(.finish(at: point))
    }

    func fill(at point: SketchPoint) {
        guard point.isValid, elements.count < maximumElements else { return }
        discardPendingPoints()
        applyFill(at: point, color: selectedColor)
        commandHandler?(.fill(at: point, color: selectedColor))
    }

    func clear() {
        guard canClear else { return }

        discardPendingPoints()
        history.append(elements)
        elements.removeAll()
        strokesAwaitingRender = []
        currentStroke = nil
        updateRenderedImage()
        commandHandler?(snapshotCommand)
    }

    func undo() {
        guard let previousElements = history.popLast() else { return }

        discardPendingPoints()
        elements = previousElements
        strokesAwaitingRender = []
        currentStroke = nil
        updateRenderedImage()
        commandHandler?(snapshotCommand)
    }

    func reset() {
        discardPendingPoints()
        renderTask?.cancel()
        renderGeneration += 1
        elements = []
        currentStroke = nil
        history = []
        strokesAwaitingRender = []
        renderedImage = nil
        selectedTool = .brush
        selectedColor = .black
    }

    func applyRemote(_ command: SketchCommand) {
        guard canApply(command) else { return }
        switch command.action {
        case .beginStroke:
            guard let point = command.point,
                  let color = command.color else {
                return
            }
            applyBeginStroke(at: point, color: color)
        case .continueStroke:
            guard let point = command.point else { return }
            applyContinueStroke(at: point)
        case .appendPoints:
            guard let points = command.points else { return }
            applyContinueStroke(points: points)
        case .finishStroke:
            guard let point = command.point else { return }
            applyFinishStroke(at: point)
        case .fill:
            guard let point = command.point,
                  let color = command.color else {
                return
            }
            applyFill(at: point, color: color)
        case .snapshot:
            discardPendingPoints()
            elements = command.elements ?? []
            currentStroke = command.currentStroke
            history = []
            strokesAwaitingRender = []
            renderedImage = nil
            updateRenderedImage()
        }
    }

    private func applyBeginStroke(
        at point: SketchPoint,
        color: SketchColor
    ) {
        currentStroke = SketchStroke(points: [point], color: color)
    }

    private func applyContinueStroke(at point: SketchPoint) {
        applyContinueStroke(points: [point])
    }

    private func applyContinueStroke(points: [SketchPoint]) {
        guard var stroke = currentStroke else { return }

        stroke.points.append(contentsOf: points)
        currentStroke = stroke
    }

    private func applyFinishStroke(at point: SketchPoint) {
        guard var finishedStroke = currentStroke else { return }

        if finishedStroke.points.last != point,
           finishedStroke.points.count < maximumPointsPerStroke {
            finishedStroke.points.append(point)
        }

        history.append(elements)
        elements.append(.stroke(finishedStroke))
        strokesAwaitingRender.append(finishedStroke)
        currentStroke = nil
        updateRenderedImage()
    }

    private func applyFill(
        at point: SketchPoint,
        color: SketchColor
    ) {
        history.append(elements)
        elements.append(
            .fill(
                SketchFill(point: point, color: color)
            )
        )
        currentStroke = nil
        updateRenderedImage()
    }

    private func updateRenderedImage() {
        renderTask?.cancel()
        renderGeneration += 1
        let generation = renderGeneration
        let snapshot = elements
        guard !snapshot.isEmpty else {
            renderedImage = nil
            return
        }

        renderTask = Task {
            let result = await renderService.render(snapshot)
            guard !Task.isCancelled, generation == renderGeneration else {
                return
            }
            renderedImage = result.image
            strokesAwaitingRender = []
        }
    }

    func canApply(
        _ command: SketchCommand,
        maximumElements: Int = SketchDrawingLimits.maximumElements,
        maximumPointsPerStroke: Int = SketchDrawingLimits.maximumPointsPerStroke
    ) -> Bool {
        guard command.isValid(
            maximumElements: maximumElements,
            maximumPointsPerStroke: maximumPointsPerStroke
        ) else { return false }

        switch command.action {
        case .beginStroke:
            return elements.count < maximumElements
                && totalPointCount < SketchDrawingLimits.maximumTotalPoints - 1
        case .continueStroke, .finishStroke:
            return currentStroke != nil
                && elements.count < maximumElements
                && (currentStroke?.points.count ?? 0) < maximumPointsPerStroke
                && totalPointCount < SketchDrawingLimits.maximumTotalPoints
        case .appendPoints:
            return currentStroke != nil
                && (currentStroke?.points.count ?? 0)
                    + (command.points?.count ?? 0) < maximumPointsPerStroke
                && totalPointCount + (command.points?.count ?? 0)
                    < SketchDrawingLimits.maximumTotalPoints
        case .fill:
            return elements.count < maximumElements
        case .snapshot:
            return true
        }
    }

    private func scheduleTransmission() {
        guard transmissionTask == nil else { return }
        transmissionTask = Task {
            try? await Task.sleep(for: .milliseconds(33))
            guard !Task.isCancelled else { return }
            flushPendingPoints()
        }
    }

    func flushPendingTransmission() {
        flushPendingPoints()
    }

    private func flushPendingPoints() {
        transmissionTask?.cancel()
        transmissionTask = nil
        guard !pendingPoints.isEmpty else { return }
        let points = pendingPoints
        pendingPoints.removeAll(keepingCapacity: true)
        commandHandler?(.append(points))
    }

    private func discardPendingPoints() {
        transmissionTask?.cancel()
        transmissionTask = nil
        pendingPoints.removeAll(keepingCapacity: true)
    }
}
