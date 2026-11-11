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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let word: WordDrop
    let containerSize: CGSize

    private let fallDuration = 4.0
    private let fadeDelay = 2.2
    private let fadeDuration = 1.8

    @State private var verticalProgress = 0.0
    @State private var opacity = 1.0

    var body: some View {
        let maximumWordWidth = min(max(containerSize.width - 20, 0), 190)
        let initialY: CGFloat = 32
        let fallDistance = max(containerSize.height / 2 - initialY, 0)
        let horizontalMargin = min(
            maximumWordWidth / 2 + 8,
            containerSize.width / 2
        )
        let availableWidth = max(containerSize.width - horizontalMargin * 2, 0)
        let horizontalPosition = CGFloat(
            min(max(word.horizontalPosition, 0), 1)
        )
        let xPosition = horizontalMargin + availableWidth * horizontalPosition

        VStack(alignment: .leading, spacing: 2) {
            Text(word.playerName)
                .font(AppTheme.font(size: 11, relativeTo: .caption2))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(word.text)
                .font(AppTheme.font(size: 18, relativeTo: .headline))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(AppTheme.text)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .frame(maxWidth: maximumWordWidth, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.text, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
        .position(x: xPosition, y: initialY)
        .offset(y: fallDistance * verticalProgress)
        .opacity(opacity)
        .task(id: reduceMotion) {
            verticalProgress = 0
            opacity = 1

            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }

            if !reduceMotion {
                withAnimation(.linear(duration: fallDuration)) {
                    verticalProgress = 1
                }
            }

            do {
                try await Task.sleep(for: .seconds(fadeDelay))
            } catch {
                return
            }

            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : fadeDuration)) {
                opacity = 0
            }
        }
    }
}

#Preview("Word Drops") {
    ZStack {
        AppTheme.background
            .ignoresSafeArea()

        WordDropOverlay(
            words: [
                WordDrop(
                    id: UUID(),
                    playerName: "Alex",
                    text: "Sketch",
                    horizontalPosition: 0.2
                ),
                WordDrop(
                    id: UUID(),
                    playerName: "Maya",
                    text: "Almost there!",
                    horizontalPosition: 0.55
                ),
                WordDrop(
                    id: UUID(),
                    playerName: "Sam",
                    text: "Pencil",
                    horizontalPosition: 0.85
                )
            ]
        )
    }
}
