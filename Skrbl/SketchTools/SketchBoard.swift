//
//  SketchBoard.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct SketchBoard: View {
    private let tools: SketchTools
    private let allowsDrawing: Bool
    private let onSkip: (() -> Void)?

    init(
        tools: SketchTools,
        allowsDrawing: Bool = true,
        onSkip: (() -> Void)? = nil
    ) {
        self.tools = tools
        self.allowsDrawing = allowsDrawing
        self.onSkip = onSkip
    }

    var body: some View {
        VStack(spacing: 0) {
            drawingCanvas

            if allowsDrawing {
                SketchToolbar(tools: tools, onSkip: onSkip)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var drawingCanvas: some View {
        GeometryReader { geometry in
            Canvas(opaque: true) { context, size in
                let boardRect = CGRect(origin: .zero, size: size)
                context.fill(Path(boardRect), with: .color(.white))

                if let renderedImage = tools.renderedImage {
                    context.draw(
                        Image(decorative: renderedImage, scale: 1),
                        in: boardRect
                    )
                }

                for stroke in tools.strokesAwaitingRender {
                    draw(stroke, in: &context, canvasSize: size)
                }

                if let currentStroke = tools.currentStroke {
                    draw(currentStroke, in: &context, canvasSize: size)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard allowsDrawing,
                              tools.selectedTool == .brush else {
                            return
                        }

                        let point = SketchPoint(
                            location: value.location,
                            in: geometry.size
                        )
                        if tools.currentStroke == nil {
                            tools.beginStroke(at: point)
                        } else {
                            tools.continueStroke(at: point)
                        }
                    }
                    .onEnded { value in
                        guard allowsDrawing else { return }

                        let point = SketchPoint(
                            location: value.location,
                            in: geometry.size
                        )
                        switch tools.selectedTool {
                        case .brush:
                            tools.finishStroke(at: point)
                        case .filler:
                            tools.fill(at: point)
                        }
                    }
            )
            .allowsHitTesting(allowsDrawing)
            .clipped()
        }
        .accessibilityLabel("Sketch board")
    }

    private func draw(
        _ stroke: SketchStroke,
        in context: inout GraphicsContext,
        canvasSize: CGSize
    ) {
        guard let firstPoint = stroke.points.first?.location(in: canvasSize) else {
            return
        }

        if stroke.points.count == 1 {
            let dot = Path(
                ellipseIn: CGRect(
                    x: firstPoint.x - 1.5,
                    y: firstPoint.y - 1.5,
                    width: 3,
                    height: 3
                )
            )
            context.fill(dot, with: .color(stroke.color.color))
            return
        }

        var path = Path()
        path.move(to: firstPoint)

        for point in stroke.points.dropFirst() {
            path.addLine(to: point.location(in: canvasSize))
        }

        context.stroke(
            path,
            with: .color(stroke.color.color),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }
}

#Preview {
    @Previewable @State var tools = SketchTools()
    SketchBoard(tools: tools)
}
