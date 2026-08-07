//
//  CreateRoomView.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct CreateRoomView: View {
    @StateObject private var connection = RoomConnectionManager()
    @State private var playerName = ""
    @State private var hasCreatedRoom = false
    @State private var selectedConnectionMode: RoomConnectionMode?

    private var normalizedName: String {
        RoomConnectionManager.normalizedPlayerName(playerName)
    }

    var body: some View {
        Group {
            if connection.isGameStarted {
                SharedSketchSessionView(connection: connection)
            } else if hasCreatedRoom {
                RoomLobbyView(
                    connection: connection,
                    showsQRCode: true
                )
            } else if let selectedConnectionMode {
                roomForm(connectionMode: selectedConnectionMode)
            } else {
                ConnectionModeSelectionView(actionTitle: "Creating a Room") {
                    selectedConnectionMode = $0
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            connection.stop()
        }
    }

    private func roomForm(connectionMode: RoomConnectionMode) -> some View {
        Form {
            Section("Connection") {
                HStack {
                    Label(connectionMode.title, systemImage: connectionMode.systemImage)
                    Spacer()
                    Button("Change") {
                        selectedConnectionMode = nil
                    }
                    .buttonStyle(WhiteOutlineButtonStyle())
                }
            }
            .listRowBackground(Color.clear)

            Section {
                TextField("Player name", text: $playerName)
                    .textFieldStyle(WhiteOutlineTextFieldStyle())
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(createRoom)
            } header: {
                Text("Your Name")
                    .foregroundStyle(AppTheme.secondaryText)
            } footer: {
                Text("The nearby room will be created under this name.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .listRowBackground(Color.clear)

            Section {
                Button(action: createRoom) {
                    Label("Create Room", systemImage: "person.2.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WhiteOutlineButtonStyle())
                .disabled(normalizedName.isEmpty)
            }
            .listRowBackground(Color.clear)

            if case .failed(let message) = connection.state {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .mainBackground()
    }

    private var navigationTitle: String {
        if connection.isGameStarted {
            return "Sketch Board"
        }
        if hasCreatedRoom {
            return connection.roomName
        }
        return selectedConnectionMode == nil ? "Connection Type" : "Create Room"
    }

    private func createRoom() {
        guard let selectedConnectionMode,
              connection.createRoom(
                playerName: normalizedName,
                connectionMode: selectedConnectionMode
              ) else {
            return
        }
        hasCreatedRoom = true
    }
}

#Preview {
    NavigationStack {
        CreateRoomView()
    }
}
