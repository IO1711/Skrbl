//
//  JoinRoomView.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct JoinRoomView: View {
    @Environment(\.dismiss) private var dismiss
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
            if connection.isShowingGameResults {
                GameResultsView(
                    rankings: connection.finalRankings,
                    onBackToRoom: connection.dismissGameResults
                )
            } else if connection.isGameStarted {
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
        .chalkBackButton(action: navigateBack)
        .edgeSwipeBack(
            isEnabled: !connection.isGameStarted,
            action: navigateBack
        )
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
        if connection.isShowingGameResults {
            return "Final Rankings"
        }
        if connection.isGameStarted {
            return "Sketch Board"
        }
        if connection.isConnected {
            return connection.roomName
        }
        if selectedConnectionMode == nil {
            return ""
        }
        return "Join Room"
    }

    private func nameEntry(connectionMode: RoomConnectionMode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connection")
                        .appTextStyle(AppTheme.chalkboardText(size: 20))

                    HStack {
                        HStack {
                            Image(connectionMode.title)
                                .resizable()
                                .frame(width: 44, height: 48)

                            Text(connectionMode.title)
                                .appTextStyle(AppTheme.chalkboardText(size: 20))
                        }

                        Spacer()

                        Button {
                            selectedConnectionMode = nil
                        } label: {
                            Image("small_button_frame")
                                .resizable()
                                .frame(width: 120, height: 60)
                                .overlay {
                                    Text("Change")
                                        .font(AppTheme.font(size: 18))
                                        .foregroundStyle(AppTheme.text)
                                }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Name")
                        .appTextStyle(AppTheme.secondaryChalkboardText(size: 20))

                    TextField("Player name", text: $playerName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .contentShape(Rectangle())
                        .overlay {
                            Image("input_frame")
                                .resizable()
                                .frame(width: 380)
                                .overlay {
                                    Image("monkey_chalk")
                                        .resizable()
                                        .frame(width: 108, height: 162)
                                        .offset(x: 100, y: -40)
                                }
                                .allowsHitTesting(false)
                        }
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit(beginSearch)

                    Text("Other players will see this name after you join.")
                        .appTextStyle(AppTheme.secondaryChalkboardText(size: 18))
                }

                Button(action: beginSearch) {
                    Image("flat_button_frame")
                        .resizable()
                        .frame(maxWidth: 347)
                        .frame(height: 55)
                        .overlay {
                            Text("Next")
                                .font(AppTheme.font(size: 18))
                                .foregroundStyle(AppTheme.text)
                        }
                }
                .frame(maxWidth: .infinity)
                .disabled(normalizedName.isEmpty)
                .opacity(normalizedName.isEmpty ? 0.45 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .buttonStyle(.plain)
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

    private func navigateBack() {
        if connection.isShowingGameResults {
            connection.dismissGameResults()
        } else if connection.isGameStarted {
            dismiss()
        } else if connection.isConnected {
            connection.stop()
            isSearching = false
            selectedConnectionMode = nil
        } else if isSearching {
            connection.stop()
            isSearching = false
        } else if selectedConnectionMode != nil {
            selectedConnectionMode = nil
        } else {
            dismiss()
        }
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

#Preview("Join Room") {
    NavigationStack {
        JoinRoomView()
    }
}
