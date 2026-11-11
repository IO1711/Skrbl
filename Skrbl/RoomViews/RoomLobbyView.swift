//
//  RoomLobbyView.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct RoomLobbyView: View {
    var connection: RoomConnectionManager
    let showsQRCode: Bool
    @State private var isShowingQRCode = false
    @State private var selectedTimeLimit = RoomConnectionManager.defaultGameSettings.timeLimit
    @State private var selectedTopic = RoomConnectionManager.defaultGameSettings.topic

    var body: some View {
        List {
            if let connectionMode = connection.connectionMode {
                Section("Connection") {
                    Label(
                        connectionMode.title,
                        systemImage: connectionMode.systemImage
                    )
                }
                .listRowBackground(Color.clear)
            }

            if showsQRCode || !connection.isConnected {
                Section {
                    Label(
                        connection.state.statusText,
                        systemImage: statusIcon
                    )
                    .foregroundStyle(statusColor)
                }
                .listRowBackground(Color.clear)
            }

            Section("Game Settings") {
                if showsQRCode {
                    Picker("Time Limit", selection: $selectedTimeLimit) {
                        ForEach(
                            RoomConnectionManager.availableTimeLimits,
                            id: \.self
                        ) { seconds in
                            Text("\(seconds) seconds")
                                .tag(seconds)
                        }
                    }
                    .whiteOutlinedControl()

                    Picker("Topic", selection: $selectedTopic) {
                        ForEach(WordTopic.allCases) { topic in
                            Text(topic.title)
                                .tag(topic)
                        }
                    }
                    .whiteOutlinedControl()

                    HStack {
                        Text("Rounds")

                        Spacer()

                        Button {
                            connection.updateNumberOfRounds(
                                connection.gameSettings.numberOfRounds - 1
                            )
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(WhiteOutlineButtonStyle())
                        .disabled(connection.gameSettings.numberOfRounds <= 1)
                        .accessibilityLabel("Decrease rounds")

                        Text("\(connection.gameSettings.numberOfRounds)")
                            .font(AppTheme.font(size: 17, relativeTo: .body))
                            .frame(minWidth: 32)

                        Button {
                            connection.updateNumberOfRounds(
                                connection.gameSettings.numberOfRounds + 1
                            )
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(WhiteOutlineButtonStyle())
                        .accessibilityLabel("Increase rounds")
                    }
                } else {
                    LabeledContent("Time Limit") {
                        Text("\(connection.gameSettings.timeLimit) seconds")
                    }

                    LabeledContent("Topic") {
                        Text(connection.gameSettings.topic.title)
                    }

                    LabeledContent("Rounds") {
                        Text("\(connection.gameSettings.numberOfRounds)")
                    }
                }
            }
            .listRowBackground(Color.clear)

            Section("Players (\(connection.players.count))") {
                ForEach(Array(connection.players.enumerated()), id: \.offset) {
                    index,
                    player in
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.text)

                        Text(player)

                        if index == 0, showsQRCode {
                            Spacer()
                            Text("Host")
                                .font(AppTheme.font(size: 12, relativeTo: .caption))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .mainBackground()
        .onChange(of: connection.gameSettings, initial: true) {
            selectedTimeLimit = connection.gameSettings.timeLimit
            selectedTopic = connection.gameSettings.topic
        }
        .onChange(of: selectedTimeLimit) {
            guard selectedTimeLimit != connection.gameSettings.timeLimit else { return }
            connection.updateTimeLimit(selectedTimeLimit)
        }
        .onChange(of: selectedTopic) {
            guard selectedTopic != connection.gameSettings.topic else { return }
            connection.updateTopic(selectedTopic)
        }
        .toolbar {
            if showsQRCode, connection.roomID != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingQRCode = true
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show room QR code")
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .sheet(isPresented: $isShowingQRCode) {
            qrCodeSheet
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsQRCode,
               connection.players.count >= 2,
               !connection.isGameStarted {
                VStack(spacing: 0) {
                    Divider()

                    Button {
                        connection.startGame()
                    } label: {
                        Label("Start Drawing", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WhiteOutlineButtonStyle())
                    .controlSize(.large)
                    .padding()
                }
                .background(AppTheme.background)
            }
        }
    }

    private var qrCodeSheet: some View {
        NavigationStack {
            Group {
                if let roomID = connection.roomID,
                   let qrImage = RoomQRCode.image(for: roomID) {
                    VStack(spacing: 16) {
                        Spacer(minLength: 12)

                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .accessibilityLabel("Room QR code")

                        Text("Scan this code to join")
                            .font(AppTheme.font(size: 17, relativeTo: .body))

                        Text(joinRequirementText)
                            .font(AppTheme.font(size: 13, relativeTo: .footnote))
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "QR Code Unavailable",
                        systemImage: "qrcode",
                        description: Text("The room QR code could not be created.")
                    )
                }
            }
            .mainBackground()
            .navigationTitle("Room QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingQRCode = false
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var joinRequirementText: String {
        switch connection.connectionMode {
        case .bluetooth:
            "The joining device must select Bluetooth and remain nearby."
        case .wifi, .none:
            "The joining device must select Wi-Fi and be on the same or peer-to-peer network."
        }
    }

    private var statusIcon: String {
        if case .failed = connection.state {
            return "exclamationmark.triangle.fill"
        }

        if connection.isConnected {
            return "checkmark.circle.fill"
        }

        return connection.connectionMode?.systemImage ?? "antenna.radiowaves.left.and.right"
    }

    private var statusColor: Color {
        if case .failed = connection.state {
            return .red
        }

        return connection.isConnected ? .green : AppTheme.secondaryText
    }
}

#Preview("Host Lobby") {
    NavigationStack {
        RoomLobbyView(
            connection: RoomConnectionManager(),
            showsQRCode: true
        )
        .navigationTitle("Room Lobby")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Guest Lobby") {
    NavigationStack {
        RoomLobbyView(
            connection: RoomConnectionManager(),
            showsQRCode: false
        )
        .navigationTitle("Room Lobby")
        .navigationBarTitleDisplayMode(.inline)
    }
}
