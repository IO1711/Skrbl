//
//  JoinRoomView.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct JoinRoomView: View {
    @State private var connection = RoomConnectionManager()
    @State private var playerName = ""
    @State private var isSearching = false
    @State private var isShowingScanner = false
    @State private var showsInvalidQRCodeAlert = false
    @State private var pendingInvalidQRCodeAlert = false
    @State private var showsScannerErrorAlert = false
    @State private var scannerError = ""
    @State private var selectedConnectionMode: RoomConnectionMode?
    @State private var isShowingRoom = false

    private var normalizedName: String {
        RoomConnectionManager.normalizedPlayerName(playerName)
    }

    var body: some View {
        Group {
            if isSearching {
                roomSearch
            } else if let selectedConnectionMode {
                nameEntry(connectionMode: selectedConnectionMode)
            } else {
                ConnectionModeSelectionView(actionTitle: "Joining a Room") {
                    selectedConnectionMode = $0
                }
            }
        }
        .navigationTitle(selectedConnectionMode == nil ? "" : "Join Room")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingRoom) {
            joinedRoom
        }
        .sheet(isPresented: $isShowingScanner, onDismiss: showScannerAlert) {
            scannerSheet
        }
        .alert("Not a Skrbl Room", isPresented: $showsInvalidQRCodeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Scan the QR code shown by a Skrbl room host.")
        }
        .alert("Scanner Unavailable", isPresented: $showsScannerErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scannerError)
        }
        .onChange(of: connection.isConnected) { _, isConnected in
            guard isConnected else { return }
            isSearching = false
            selectedConnectionMode = nil
            isShowingRoom = true
        }
        .onChange(of: isShowingRoom) { wasShowingRoom, isShowingRoom in
            if wasShowingRoom, !isShowingRoom {
                connection.stop()
            }
        }
        .onDisappear {
            if !isShowingRoom {
                connection.stop()
            }
        }
    }

    @ViewBuilder
    private var joinedRoom: some View {
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
                    showsQRCode: false
                )
            }
        }
        .navigationTitle(joinedRoomNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(connection.isGameStarted)
        .toolbar {
            if connection.isGameStarted {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingRoom = false
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

    private var joinedRoomNavigationTitle: String {
        if connection.isShowingGameResults {
            return "Final Rankings"
        }
        if connection.isGameStarted {
            return "Sketch Board"
        }
        return connection.roomName
    }

    private func nameEntry(connectionMode: RoomConnectionMode) -> some View {
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
                        .submitLabel(.next)
                        .onSubmit(beginSearch)

                    Text("Other players will see this name after you join.")
                        .appTextStyle(AppTheme.secondaryChalkboardText(size: 18))
                }

                Button(action: beginSearch) {
                    ChalkButtonLabel(title: "Next", expandsWidth: true)
                        .frame(maxWidth: 347)
                }
                .frame(maxWidth: .infinity)
                .disabled(normalizedName.isEmpty)
                .opacity(normalizedName.isEmpty ? 0.7 : 1)
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
                    scannerError = ""
                    pendingInvalidQRCodeAlert = false
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
                    pendingInvalidQRCodeAlert = true
                    return
                }

                isShowingScanner = false
                connection.joinRoom(withID: roomID)
            } onError: { message in
                scannerError = message
                isShowingScanner = false
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

    private func showScannerAlert() {
        if !scannerError.isEmpty {
            showsScannerErrorAlert = true
        } else if pendingInvalidQRCodeAlert {
            showsInvalidQRCodeAlert = true
            pendingInvalidQRCodeAlert = false
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

#Preview("Join Room") {
    NavigationStack {
        JoinRoomView()
    }
}
