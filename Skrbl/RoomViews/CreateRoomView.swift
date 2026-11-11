//
//  CreateRoomView.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct CreateRoomView: View {
    @State private var connection = RoomConnectionManager()
    @State private var playerName = ""
    @State private var hasCreatedRoom = false
    @State private var selectedConnectionMode: RoomConnectionMode?

    init(initialConnectionMode: RoomConnectionMode? = nil) {
        _selectedConnectionMode = State(initialValue: initialConnectionMode)
    }

    private var normalizedName: String {
        RoomConnectionManager.normalizedPlayerName(playerName)
    }

    var body: some View {
        Group {
            if let selectedConnectionMode {
                roomForm(connectionMode: selectedConnectionMode)
            } else {
                ConnectionModeSelectionView(actionTitle: "Creating a Room") {
                    selectedConnectionMode = $0
                }
            }
        }
        .navigationTitle(selectedConnectionMode == nil ? "" : "Create Room")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $hasCreatedRoom) {
            hostedRoom
        }
        .onChange(of: hasCreatedRoom) { wasShowingRoom, isShowingRoom in
            if wasShowingRoom, !isShowingRoom {
                connection.stop()
            }
        }
        .onDisappear {
            if !hasCreatedRoom {
                connection.stop()
            }
        }
    }

    @ViewBuilder
    private var hostedRoom: some View {
        Group {
            if connection.isShowingGameResults {
                GameResultsView(
                    rankings: connection.finalRankings,
                    onBackToRoom: connection.dismissGameResults
                )
            } else if connection.isGameStarted {
                SharedSketchSessionView(connection: connection)
            } else {
                RoomLobbyView(
                    connection: connection,
                    showsQRCode: true
                )
            }
        }
        .navigationTitle(hostedRoomNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(connection.isGameStarted)
        .toolbar {
            if connection.isGameStarted {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        hasCreatedRoom = false
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    private func roomForm(connectionMode: RoomConnectionMode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                RoomConnectionHeader(mode: connectionMode) {
                    selectedConnectionMode = nil
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Name")
                        .appTextStyle(AppTheme.secondaryChalkboardText(size: 20))

                    TextField(
                        "Player name",
                        text: $playerName,
                        prompt: Text("Player name")
                            .foregroundColor(AppTheme.secondaryText)
                    )
                        .textFieldStyle(.plain)
                        .foregroundStyle(AppTheme.text)
                        .tint(AppTheme.text)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                        .contentShape(Rectangle())
                        .overlay {
                            Image(decorative: "input_frame")
                                .resizable()
                                .allowsHitTesting(false)
                        }
                        .overlay {
                            GeometryReader { geometry in
                                let scale = min(1, geometry.size.width / 380)

                                Image(decorative: "monkey_chalk")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 108 * scale, height: 162 * scale)
                                    .position(
                                        x: geometry.size.width / 2 + 100 * scale,
                                        y: geometry.size.height / 2 - 40 * scale
                                    )
                            }
                            .allowsHitTesting(false)
                        }
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(createRoom)

                    Text("The room will be created under this name.")
                        .appTextStyle(AppTheme.secondaryChalkboardText(size: 18))
                }

                Button(action: createRoom) {
                    ChalkButtonLabel(title: "Create room", expandsWidth: true)
                        .frame(maxWidth: 347)
                }
                .frame(maxWidth: .infinity)
                .disabled(normalizedName.isEmpty)
                .opacity(normalizedName.isEmpty ? 0.7 : 1)

                if case .failed(let message) = connection.state {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .buttonStyle(.plain)
        .mainBackground()
    }

    private var hostedRoomNavigationTitle: String {
        if connection.isShowingGameResults {
            return "Final Rankings"
        }
        if connection.isGameStarted {
            return "Sketch Board"
        }
        return connection.roomName
    }

    private func createRoom() {
        guard let selectedConnectionMode,
              connection.createRoom(
                playerName: normalizedName,
                connectionMode: selectedConnectionMode
              ) else {
            return
        }
        self.selectedConnectionMode = nil
        hasCreatedRoom = true
    }
}

#Preview("Create Room") {
    NavigationStack {
        CreateRoomView(initialConnectionMode: .wifi)
    }
}
