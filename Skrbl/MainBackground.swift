//
//  MainBackground.swift
//  Skrbl
//
//  Created by Codex on 02/08/2026.
//

import SwiftUI

enum AppTheme {
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
}

private struct MainBackground: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
    }
}

extension View {
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
