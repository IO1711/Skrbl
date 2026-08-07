//
//  JoinRoomView.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct JoinRoomView: View {
    @StateObject private var connection = RoomConnectionManager()
    @State private var playerName = ""
    @State private var isSearching = false
    @State private var isShowingScanner = false
    @State private var showsInvalidQRCodeAlert = false
    @State private var selectedConnectionMode: RoomConnectionMode?

    private var normalizedName: String {
        RoomConnectionManager.normalizedPlayerName(playerName)
    }

    var body: some View {
        Group {
            if connection.isGameStarted {
                SharedSketchSessionView(connection: connection)
            } else if connection.isConnected {
                RoomLobbyView(
                    connection: connection,
                    showsQRCode: false
                )
            } else if isSearching {
                roomSearch
            } else if let selectedConnectionMode {
                nameEntry(connectionMode: selectedConnectionMode)
            } else {
                ConnectionModeSelectionView(actionTitle: "Joining a Room") {
                    selectedConnectionMode = $0
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingScanner) {
            scannerSheet
        }
        .alert("Not a Skrbl Room", isPresented: $showsInvalidQRCodeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Scan the QR code shown by a Skrbl room host.")
        }
        .onDisappear {
            connection.stop()
        }
    }

    private var navigationTitle: String {
        if connection.isGameStarted {
            return "Sketch Board"
        }
        if connection.isConnected {
            return connection.roomName
        }
        if selectedConnectionMode == nil {
            return "Connection Type"
        }
        return "Join Room"
    }

    private func nameEntry(connectionMode: RoomConnectionMode) -> some View {
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
                    .submitLabel(.next)
                    .onSubmit(beginSearch)
            } header: {
                Text("Your Name")
                    .foregroundStyle(AppTheme.secondaryText)
            } footer: {
                Text("Other players will see this name after you join.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .listRowBackground(Color.clear)

            Section {
                Button(action: beginSearch) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WhiteOutlineButtonStyle())
                .disabled(normalizedName.isEmpty)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .mainBackground()
    }

    private var roomSearch: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    if showsProgress {
                        ProgressView()
                    }

                    Text(connection.state.statusText)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .listRowBackground(Color.clear)

            Section("Available Rooms") {
                if connection.nearbyRooms.isEmpty {
                    ContentUnavailableView(
                        "No Rooms Yet",
                        systemImage: selectedConnectionMode?.systemImage ?? "antenna.radiowaves.left.and.right",
                        description: Text(
                            "Keep this screen open while nearby hosts are discovered."
                        )
                    )
                } else {
                    ForEach(connection.nearbyRooms) { room in
                        Button {
                            connection.join(room)
                        } label: {
                            HStack {
                                Label(
                                    room.roomName,
                                    systemImage: "person.2.fill"
                                )
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                        }
                        .buttonStyle(WhiteOutlineButtonStyle())
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listRowBackground(Color.clear)

            Section {
                Button {
                    isShowingScanner = true
                } label: {
                    Label("Scan Room QR Code", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WhiteOutlineButtonStyle())

                if case .failed = connection.state {
                    Button(action: restartSearch) {
                        Label("Search Again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WhiteOutlineButtonStyle())
                }
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .mainBackground()
    }

    private var scannerSheet: some View {
        NavigationStack {
            RoomQRScanner { payload in
                guard let roomID = RoomQRCode.roomID(from: payload) else {
                    isShowingScanner = false
                    showsInvalidQRCodeAlert = true
                    return
                }

                isShowingScanner = false
                connection.joinRoom(withID: roomID)
            }
            .ignoresSafeArea()
            .navigationTitle("Scan Room Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isShowingScanner = false
                    }
                }
            }
        }
    }

    private func beginSearch() {
        guard !normalizedName.isEmpty,
              let selectedConnectionMode else {
            return
        }
        isSearching = true
        connection.startSearching(
            playerName: normalizedName,
            connectionMode: selectedConnectionMode
        )
    }

    private func restartSearch() {
        guard let selectedConnectionMode else { return }
        connection.startSearching(
            playerName: normalizedName,
            connectionMode: selectedConnectionMode
        )
    }

    private var showsProgress: Bool {
        switch connection.state {
        case .searching, .waitingForScannedRoom, .connecting:
            true
        default:
            false
        }
    }
}

#Preview {
    NavigationStack {
        JoinRoomView()
    }
}
