import CoreGraphics
import Foundation
import Testing
@testable import Skrbl

@MainActor
struct SketchToolsTests {
    private func point(_ x: CGFloat, _ y: CGFloat) -> SketchPoint {
        SketchPoint(location: CGPoint(x: x, y: y), in: CGSize(width: 1, height: 1))
    }

    @Test func drawingStructureAndCumulativeLimitsAreEnforced() {
        let origin = point(0, 0)
        #expect(!SketchCommand.append([]).isValid())
        #expect(!SketchCommand.append(Array(repeating: origin, count: 65)).isValid())
        let oversizedStroke = SketchStroke(points: Array(repeating: origin, count: 4_097), color: .black)
        #expect(!SketchCommand.snapshot(elements: [.stroke(oversizedStroke)], currentStroke: nil).isValid())
        let invalidElement = SketchElement(
            kind: .stroke, stroke: nil, fill: SketchFill(point: origin, color: .red)
        )
        #expect(!SketchCommand.snapshot(elements: [invalidElement], currentStroke: nil).isValid())
        #expect(!SketchCommand.snapshot(
            elements: [.fill(SketchFill(point: origin, color: .red))],
            currentStroke: SketchStroke(points: [origin], color: .black)
        ).isValid(maximumElements: 1))
        let fullStroke = SketchStroke(points: Array(repeating: origin, count: 4_096), color: .black)
        #expect(!SketchCommand.snapshot(
            elements: Array(repeating: .stroke(fullStroke), count: 3),
            currentStroke: nil
        ).isValid())
        let tools = SketchTools()
        #expect(!tools.canApply(.append([origin])))
        tools.applyRemote(.snapshot(
            elements: [],
            currentStroke: SketchStroke(points: Array(repeating: origin, count: 4_095), color: .black)
        ))
        #expect(!tools.canApply(.append([origin])))
        #expect(tools.canApply(.finish(at: point(1, 1))))
        tools.reset()
    }

    @Test func strokePointsAreBatchedBeforeFinish() async throws {
        let tools = SketchTools()
        var commands: [SketchCommand] = []
        tools.commandHandler = { commands.append($0) }
        tools.beginStroke(at: point(0, 0))
        for _ in 0..<100 { tools.continueStroke(at: point(0, 0)) }
        #expect(commands.count == 1)
        try await Task.sleep(for: .milliseconds(20))
        tools.continueStroke(at: point(0.5, 0.5))
        tools.finishStroke(at: point(1, 1))
        #expect(commands.map(\.action) == [.beginStroke, .appendPoints, .finishStroke])
        #expect(commands[1].points?.count == 1)
        #expect(tools.elements.first?.stroke?.points.count == 3)

        let remote = SketchTools()
        for command in commands { remote.applyRemote(command) }
        #expect(remote.elements == tools.elements)
        tools.reset()
        remote.reset()
    }

    @Test func resetDiscardsPendingTransmissionAndRender() async throws {
        let tools = SketchTools()
        var commands: [SketchCommand] = []
        tools.commandHandler = { commands.append($0) }
        tools.beginStroke(at: point(0, 0))
        try await Task.sleep(for: .milliseconds(20))
        tools.continueStroke(at: point(0.5, 0.5))
        tools.reset()
        try await Task.sleep(for: .milliseconds(60))
        #expect(commands.map(\.action) == [.beginStroke])
        #expect(tools.elements.isEmpty)
        #expect(tools.renderedImage == nil)
    }

    @Test func clearCannotBeOverwrittenByAnOlderRender() async throws {
        let tools = SketchTools()
        tools.fill(at: point(0.5, 0.5))
        tools.clear()
        try await Task.sleep(for: .milliseconds(100))
        #expect(tools.elements.isEmpty)
        #expect(tools.renderedImage == nil)
        tools.reset()
    }

    @Test func pendingPointsFlushBeforeJoiningSnapshot() async throws {
        let tools = SketchTools()
        var commands: [SketchCommand] = []
        tools.commandHandler = { commands.append($0) }
        tools.beginStroke(at: point(0, 0))
        try await Task.sleep(for: .milliseconds(20))
        tools.continueStroke(at: point(0.5, 0.5))
        tools.flushPendingTransmission()
        #expect(commands.map(\.action) == [.beginStroke, .appendPoints])
        let remote = SketchTools()
        remote.applyRemote(tools.snapshotCommand)
        commands.removeAll()
        tools.finishStroke(at: point(1, 1))
        for command in commands { remote.applyRemote(command) }
        #expect(remote.elements == tools.elements)
        tools.reset()
        remote.reset()
    }

    @Test func batchTimerSendsAnUnfinishedStroke() async throws {
        let tools = SketchTools()
        var commands: [SketchCommand] = []
        tools.commandHandler = { commands.append($0) }
        tools.beginStroke(at: point(0, 0))
        try await Task.sleep(for: .milliseconds(20))
        tools.continueStroke(at: point(0.5, 0.5))
        try await Task.sleep(for: .milliseconds(60))
        #expect(commands.map(\.action) == [.beginStroke, .appendPoints])
        #expect(tools.currentStroke != nil)
        tools.reset()
    }

    @Test func renderActorProducesTheRequestedFill() async throws {
        let result = await SketchRenderService().render([
            .fill(SketchFill(point: point(0.5, 0.5), color: .red))
        ])
        let image = try #require(result.image)
        let data = try #require(image.dataProvider?.data) as Data
        #expect(image.width == 512)
        #expect(Array(data.prefix(4)) == [230, 52, 64, 255])
    }
}
