//
//  WordDropOverlay.swift
//  Skrbl
//
//  Created by Codex on 31/07/2026.
//

import SwiftUI

struct WordDropOverlay: View {
    let words: [WordDrop]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(words) { word in
                    AnimatedWordDrop(
                        word: word,
                        containerSize: geometry.size
                    )
                }
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .topLeading
            )
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct AnimatedWordDrop: View {
    let word: WordDrop
    let containerSize: CGSize

    @State private var verticalProgress = 0.0
    @State private var opacity = 1.0

    var body: some View {
        let maximumWordWidth = min(max(containerSize.width - 24, 0), 220)
        let horizontalMargin = min(
            maximumWordWidth / 2 + 8,
            containerSize.width / 2
        )
        let availableWidth = max(containerSize.width - horizontalMargin * 2, 0)
        let horizontalPosition = CGFloat(
            min(max(word.horizontalPosition, 0), 1)
        )
        let xPosition = horizontalMargin + availableWidth * horizontalPosition

        Text(word.text)
            .font(AppTheme.font(size: 20))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .foregroundStyle(AppTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: maximumWordWidth)
            .background(Color.clear)
            .overlay {
                Capsule()
                    .stroke(AppTheme.text, lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
            .position(x: xPosition, y: 28)
            .offset(y: containerSize.height * 0.30 * verticalProgress)
            .opacity(opacity)
            .task(id: word.id) {
                await Task.yield()
                withAnimation(.easeInOut(duration: 3.8)) {
                    verticalProgress = 1
                }

                do {
                    try await Task.sleep(for: .seconds(2.3))
                } catch {
                    return
                }

                withAnimation(.easeOut(duration: 1.5)) {
                    opacity = 0
                }
            }
    }
}
