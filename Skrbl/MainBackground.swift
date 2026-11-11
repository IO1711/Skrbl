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

    static func font(
        size: CGFloat,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        .custom("Chalkduster", size: size, relativeTo: style)
    }

    static func chalkboardText(
        size: CGFloat,
        relativeTo style: Font.TextStyle = .body
    ) -> TextStyle {
        TextStyle(
            font: .custom("ChalkboardSE-Regular", size: size, relativeTo: style),
            color: text
        )
    }

    static func secondaryChalkboardText(size: CGFloat) -> TextStyle {
        TextStyle(
            font: .custom("ChalkboardSE-Regular", size: size, relativeTo: .body),
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

extension View {
    func appTextStyle(_ style: AppTheme.TextStyle) -> some View {
        modifier(style)
    }

    func mainBackground() -> some View {
        foregroundStyle(AppTheme.text)
            .tint(AppTheme.text)
            .background {
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

}

struct WhiteOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.font(size: 16, relativeTo: .body))
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
            .font(AppTheme.font(size: 16, relativeTo: .body))
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
