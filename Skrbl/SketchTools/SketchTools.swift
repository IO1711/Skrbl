//
//  SketchTools.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import Combine
import SwiftUI
import UIKit

enum SketchTool: String, CaseIterable, Identifiable {
    case brush
    case filler

    var id: String {
        rawValue
    }
}

struct SketchRGBA {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

enum SketchColor: String, Codable, CaseIterable, Identifiable {
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

    var rgba: SketchRGBA {
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

    var color: Color {
        let rgba = rgba
        return Color(
            red: Double(rgba.red) / 255,
            green: Double(rgba.green) / 255,
            blue: Double(rgba.blue) / 255,
            opacity: Double(rgba.alpha) / 255
        )
    }

    func menuIcon(isSelected: Bool) -> Image {
        let rgba = rgba
        let uiColor = UIColor(
            red: CGFloat(rgba.red) / 255,
            green: CGFloat(rgba.green) / 255,
            blue: CGFloat(rgba.blue) / 255,
            alpha: CGFloat(rgba.alpha) / 255
        )
        let symbolName = isSelected ? "checkmark.circle.fill" : "circle.fill"
        let image = UIImage(systemName: symbolName)?
            .withTintColor(uiColor, renderingMode: .alwaysOriginal)

        return Image(uiImage: image ?? UIImage())
    }
}

struct SketchPoint: Codable, Equatable {
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
}

struct SketchStroke: Codable, Equatable {
    var points: [SketchPoint]
    let color: SketchColor
}

struct SketchFill: Codable, Equatable {
    let point: SketchPoint
    let color: SketchColor
}

struct SketchElement: Codable, Equatable {
    enum Kind: String, Codable {
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

struct SketchCommand: Codable {
    enum Action: String, Codable {
        case beginStroke
        case continueStroke
        case finishStroke
        case fill
        case snapshot
    }

    let action: Action
    let point: SketchPoint?
    let color: SketchColor?
    let elements: [SketchElement]?
    let currentStroke: SketchStroke?

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
}

@MainActor
final class SketchTools: ObservableObject {
    @Published private(set) var elements: [SketchElement] = []
    @Published private(set) var currentStroke: SketchStroke?
    @Published private(set) var renderedImage: CGImage?
    @Published var selectedTool: SketchTool = .brush
    @Published var selectedColor: SketchColor = .black

    var commandHandler: ((SketchCommand) -> Void)?

    private var history: [[SketchElement]] = []

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
        applyBeginStroke(at: point, color: selectedColor)
        commandHandler?(.begin(at: point, color: selectedColor))
    }

    func continueStroke(at point: SketchPoint) {
        applyContinueStroke(at: point)
        commandHandler?(.continueStroke(at: point))
    }

    func finishStroke(at point: SketchPoint) {
        guard currentStroke != nil else { return }

        applyFinishStroke(at: point)
        commandHandler?(.finish(at: point))
    }

    func fill(at point: SketchPoint) {
        applyFill(at: point, color: selectedColor)
        commandHandler?(.fill(at: point, color: selectedColor))
    }

    func clear() {
        guard canClear else { return }

        history.append(elements)
        elements.removeAll()
        currentStroke = nil
        updateRenderedImage()
        commandHandler?(snapshotCommand)
    }

    func undo() {
        guard let previousElements = history.popLast() else { return }

        elements = previousElements
        currentStroke = nil
        updateRenderedImage()
        commandHandler?(snapshotCommand)
    }

    func reset() {
        elements = []
        currentStroke = nil
        history = []
        renderedImage = nil
        selectedTool = .brush
        selectedColor = .black
    }

    func applyRemote(_ command: SketchCommand) {
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
            elements = command.elements ?? []
            currentStroke = command.currentStroke
            history = []
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
        guard var stroke = currentStroke else { return }

        stroke.points.append(point)
        currentStroke = stroke
    }

    private func applyFinishStroke(at point: SketchPoint) {
        guard var finishedStroke = currentStroke else { return }

        if finishedStroke.points.last != point {
            finishedStroke.points.append(point)
        }

        history.append(elements)
        elements.append(.stroke(finishedStroke))
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
        renderedImage = SketchRenderer.render(elements)
    }
}

struct SketchToolbar: View {
    @ObservedObject var tools: SketchTools
    let onSkip: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(SketchTool.allCases) { tool in
                    Button {
                        tools.selectedTool = tool
                    } label: {
                        Label(
                            tool == .brush ? "Brush" : "Filler",
                            systemImage: tool == .brush
                                ? "paintbrush.fill"
                                : "paintbucket.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        WhiteOutlineButtonStyle(
                            isSelected: tools.selectedTool == tool
                        )
                    )
                }

                colorPalette
            }

            HStack(spacing: 12) {
                Button {
                    tools.clear()
                } label: {
                    Label("Eraser", systemImage: "eraser")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!tools.canClear)

                Button {
                    tools.undo()
                } label: {
                    Label("Back", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!tools.canUndo)

                if let onSkip {
                    Button(action: onSkip) {
                        Label("Skip", systemImage: "forward.end.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(WhiteOutlineButtonStyle())
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.background)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var colorPalette: some View {
        Menu {
            ForEach(SketchColor.allCases) { color in
                Button {
                    tools.selectedColor = color
                } label: {
                    Label {
                        Text(color.displayName)
                    } icon: {
                        color.menuIcon(isSelected: tools.selectedColor == color)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")

                Circle()
                    .fill(tools.selectedColor.color)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .stroke(Color.secondary, lineWidth: 1)
                    }
            }
            .frame(minWidth: 58)
        }
        .buttonStyle(WhiteOutlineButtonStyle())
        .accessibilityLabel("Brush color: \(tools.selectedColor.displayName)")
    }
}
