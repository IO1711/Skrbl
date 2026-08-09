//
//  MainBackground.swift
//  Skrbl
//
//  Created by Codex on 02/08/2026.
//

import SwiftUI

enum AppTheme {
    struct TextStyle: ViewModifier {
        let font: Font
        let color: Color

        func body(content: Content) -> some View {
            content
                .font(font)
                .foregroundStyle(color)
        }
    }

    static let background = Color(
        red: 9.0 / 255.0,
        green: 53.0 / 255.0,
        blue: 11.0 / 255.0
    )
    static let text = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let tertiaryText = Color.white.opacity(0.52)

    static func font(size: CGFloat) -> Font {
        .custom("Chalkduster", size: size)
    }

    static func chalkboardText(size: CGFloat) -> TextStyle {
        TextStyle(
            font: .custom("ChalkboardSE-Regular", size: size),
            color: text
        )
    }

    static func secondaryChalkboardText(size: CGFloat) -> TextStyle {
        TextStyle(
            font: .custom("ChalkboardSE-Regular", size: size),
            color: secondaryText
        )
    }
}

private struct MainBackground: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
    }
}

private struct ChalkBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let action {
                            action()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image("back_chalk")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

private struct EdgeSwipeBackModifier: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontalDistance = value.translation.width
                        let verticalDistance = abs(value.translation.height)

                        guard value.startLocation.x <= 32,
                              horizontalDistance >= 80,
                              horizontalDistance > verticalDistance * 1.25 else {
                            return
                        }

                        action()
                    }
            )
        } else {
            content
        }
    }
}

extension View {
    func appTextStyle(_ style: AppTheme.TextStyle) -> some View {
        modifier(style)
    }

    func mainBackground() -> some View {
        background {
            MainBackground()
        }
    }

    func whiteOutlinedControl(cornerRadius: CGFloat = 10) -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.text, lineWidth: 1.5)
            }
    }

    func chalkBackButton(action: (() -> Void)? = nil) -> some View {
        modifier(ChalkBackButtonModifier(action: action))
    }

    func edgeSwipeBack(
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        modifier(
            EdgeSwipeBackModifier(
                isEnabled: isEnabled,
                action: action
            )
        )
    }
}

struct WhiteOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.font(size: 16))
            .foregroundStyle(AppTheme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        AppTheme.text.opacity(isEnabled ? 1 : 0.4),
                        lineWidth: isSelected ? 3 : 1.5
                    )
            }
            .opacity(configuration.isPressed ? 0.65 : (isEnabled ? 1 : 0.45))
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct WhiteOutlineTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(AppTheme.font(size: 16))
            .foregroundStyle(AppTheme.text)
            .tint(AppTheme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.text, lineWidth: 1.5)
            }
    }
}
