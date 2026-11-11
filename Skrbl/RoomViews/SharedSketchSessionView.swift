//
//  SharedSketchSessionView.swift
//  Skrbl
//
//  Created by Codex on 31/07/2026.
//

import Combine
import SwiftUI
import UIKit

private struct GuessFieldFramePreferenceKey: PreferenceKey {
    static var defaultValue = CGRect.null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct SharedSketchSessionView: View {
    var connection: RoomConnectionManager
    @State private var viewerWord = ""
    @State private var keyboardOverlap: CGFloat = 0
    @State private var guessFieldFrame = CGRect.null
    @FocusState private var isViewerWordFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    turnStatus

                    if connection.gamePhase == .drawing {
                        guessProgress

                        if !connection.wordHint.isEmpty {
                            wordHintStrip
                        }
                    }

                    gameplayContent

                    if connection.canSubmitWord {
                        wordComposer
                            .offset(y: -keyboardOverlap)
                    } else if connection.gamePhase == .drawing,
                              connection.localPlayerHasGuessed {
                        correctGuessBanner
                    }
                }

                WordDropOverlay(words: connection.activeWordDrops)
            }
            .coordinateSpace(name: "gameSession")
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .onPreferenceChange(GuessFieldFramePreferenceKey.self) {
                guessFieldFrame = $0
            }
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    guard isViewerWordFocused,
                          !guessFieldFrame.contains(value.location) else {
                        return
                    }
                    isViewerWordFocused = false
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillChangeFrameNotification
                )
            ) { notification in
                updateKeyboardOverlap(notification, in: geometry)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .mainBackground()
        .onChange(of: connection.currentDrawerID) {
            viewerWord = ""
            isViewerWordFocused = false
            keyboardOverlap = 0
            guessFieldFrame = .null
        }
    }

    @ViewBuilder
    private var gameplayContent: some View {
        switch connection.gamePhase {
        case .lobby:
            waitingPanel(
                title: "Preparing the game…",
                systemImage: "hourglass"
            )
        case .choosingWord:
            if connection.isChoosingWord {
                wordChoicePanel
            } else {
                waitingPanel(
                    title: "Waiting for the word selection…",
                    systemImage: "text.word.spacing"
                )
            }
        case .drawing:
            SketchBoard(
                tools: connection.sketchTools,
                allowsDrawing: connection.canDraw,
                onSkip: connection.skipTurn
            )
        }
    }

    private var turnStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: turnStatusIcon)
                .foregroundStyle(
                    connection.canDraw ? AppTheme.text : AppTheme.secondaryText
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(turnStatusText)
                    .font(AppTheme.font(size: 15, relativeTo: .subheadline))

                Text(roundDetailText)
                    .font(AppTheme.font(size: 12, relativeTo: .caption))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Text("\(connection.localPlayerScore) pts")
                .font(AppTheme.font(size: 13, relativeTo: .footnote))
                .monospacedDigit()
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .overlay {
                    Capsule()
                        .stroke(AppTheme.text, lineWidth: 1.5)
                }

            if connection.gamePhase == .drawing {
                Label(formattedTime, systemImage: "timer")
                    .font(AppTheme.font(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(
                        connection.remainingSeconds <= 10 ? Color.red : AppTheme.text
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.clear)
                    .overlay {
                        Capsule()
                            .stroke(AppTheme.text, lineWidth: 1.5)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.background)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var guessProgress: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(
                    Array(zip(connection.playerIDs, connection.players)),
                    id: \.0
                ) { playerID, playerName in
                    if playerID != connection.currentDrawerID {
                        let hasGuessed = connection.hasGuessed(playerID: playerID)

                        Label(
                            "\(playerName) • \(connection.score(for: playerID)) pts",
                            systemImage: hasGuessed
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .font(AppTheme.font(size: 12, relativeTo: .caption))
                        .foregroundStyle(
                            hasGuessed ? Color.green : AppTheme.secondaryText
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.clear)
                        .overlay {
                            Capsule()
                                .stroke(
                                    hasGuessed ? Color.green : AppTheme.text,
                                    lineWidth: 1.5
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var wordHintStrip: some View {
        Text(connection.wordHint)
            .font(AppTheme.font(size: 20, relativeTo: .title3))
            .foregroundStyle(AppTheme.text)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.background)
            .overlay(alignment: .bottom) {
                Divider()
            }
            .accessibilityLabel("Word hint: \(connection.wordHint)")
    }

    private var wordChoicePanel: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "text.word.spacing")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.text)

            VStack(spacing: 6) {
                Text("Choose a Word")
                    .font(AppTheme.font(size: 22, relativeTo: .title2))

                Text("Your timer starts after you choose.")
                    .font(AppTheme.font(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if connection.wordChoices.isEmpty {
                ProgressView("Loading choices…")
            } else {
                VStack(spacing: 12) {
                    ForEach(connection.wordChoices, id: \.self) { word in
                        Button {
                            connection.selectWord(word)
                        } label: {
                            Text(word)
                                .font(AppTheme.font(size: 17, relativeTo: .body))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(WhiteOutlineButtonStyle())
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    private func waitingPanel(
        title: String,
        systemImage: String
    ) -> some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.secondaryText)

            Text(title)
                .font(AppTheme.font(size: 17, relativeTo: .body))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    private var wordComposer: some View {
        HStack(spacing: 10) {
            TextField(
                "Type your guess",
                text: $viewerWord,
                prompt: Text("Type your guess")
                    .foregroundColor(AppTheme.secondaryText)
            )
                .textFieldStyle(WhiteOutlineTextFieldStyle())
                .focused($isViewerWordFocused)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: GuessFieldFramePreferenceKey.self,
                            value: geometry.frame(in: .named("gameSession"))
                        )
                    }
                }
                .textInputAutocapitalization(.never)
                .submitLabel(.send)
                .onSubmit(sendWord)
                .onChange(of: viewerWord) { _, newValue in
                    if newValue.count > 32 {
                        viewerWord = String(newValue.prefix(32))
                    }
                }

            Button(action: sendWord) {
                Image(systemName: "paperplane.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(WhiteOutlineButtonStyle())
            .disabled(
                viewerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .accessibilityLabel("Send guess")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.background)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var correctGuessBanner: some View {
        Label(
            "Correct! Score: \(connection.localPlayerScore) points",
            systemImage: "checkmark.circle.fill"
        )
            .font(AppTheme.font(size: 17, relativeTo: .body))
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.background)
            .overlay(alignment: .top) {
                Divider()
            }
    }

    private var turnStatusIcon: String {
        switch connection.gamePhase {
        case .lobby:
            "hourglass"
        case .choosingWord:
            connection.isChoosingWord ? "text.word.spacing" : "eye.fill"
        case .drawing:
            connection.canDraw ? "pencil.circle.fill" : "eye.fill"
        }
    }

    private var turnStatusText: String {
        switch connection.gamePhase {
        case .lobby:
            "Preparing the game…"
        case .choosingWord:
            if connection.isChoosingWord {
                "Choose one of three words"
            } else if let currentDrawerName = connection.currentDrawerName {
                "\(currentDrawerName) is choosing a word"
            } else {
                "Waiting for the next player…"
            }
        case .drawing:
            if connection.canDraw {
                "Your turn to draw"
            } else if let currentDrawerName = connection.currentDrawerName {
                "\(currentDrawerName) is drawing"
            } else {
                "Waiting for the next turn…"
            }
        }
    }

    private var roundDetailText: String {
        let round = "Round \(connection.currentRound) of \(connection.gameSettings.numberOfRounds)"
        if connection.canDraw,
           let wordToDraw = connection.wordToDraw {
            return "\(round) • Draw: \(wordToDraw)"
        }
        return round
    }

    private var formattedTime: String {
        let seconds = max(connection.remainingSeconds, 0)
        return Duration.seconds(seconds)
            .formatted(.time(pattern: .minuteSecond))
    }

    private func sendWord() {
        if connection.sendWord(viewerWord) {
            viewerWord = ""
        }
    }

    private func updateKeyboardOverlap(
        _ notification: Notification,
        in geometry: GeometryProxy
    ) {
        guard let keyboardFrame = notification.userInfo?[
            UIResponder.keyboardFrameEndUserInfoKey
        ] as? CGRect else {
            return
        }

        let viewFrame = geometry.frame(in: .global)
        let overlap = max(viewFrame.maxY - keyboardFrame.minY, 0)
        let duration = (
            notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
                as? NSNumber
        )?.doubleValue ?? 0.25

        withAnimation(.easeOut(duration: duration)) {
            keyboardOverlap = isViewerWordFocused ? overlap : 0
        }
    }
}

#Preview("Shared Sketch Session") {
    NavigationStack {
        SharedSketchSessionView(connection: RoomConnectionManager())
            .navigationTitle("Sketch Board")
            .navigationBarTitleDisplayMode(.inline)
    }
}
