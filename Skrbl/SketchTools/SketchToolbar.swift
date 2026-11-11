import SwiftUI

struct SketchToolbar: View {
    var tools: SketchTools
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
