//
//  RoomLobbyView.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct RoomLobbyView: View {
    @ObservedObject var connection: RoomConnectionManager
    let showsQRCode: Bool

    var body: some View {
        List {
            if showsQRCode,
               let roomID = connection.roomID,
               let qrImage = RoomQRCode.image(for: roomID) {
                Section {
                    VStack(spacing: 14) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .accessibilityLabel("Room QR code")

                        Text("Scan this code to join")
                            .font(AppTheme.font(size: 17))

                        Text(joinRequirementText)
                            .font(AppTheme.font(size: 13))
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
            }

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
                    Picker("Time Limit", selection: timeLimitBinding) {
                        ForEach(
                            RoomConnectionManager.availableTimeLimits,
                            id: \.self
                        ) { seconds in
                            Text("\(seconds) seconds")
                                .tag(seconds)
                        }
                    }
                    .whiteOutlinedControl()

                    Picker("Topic", selection: topicBinding) {
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
                            .font(AppTheme.font(size: 17))
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
                                .font(AppTheme.font(size: 12))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .mainBackground()
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

    private var timeLimitBinding: Binding<Int> {
        Binding(
            get: { connection.gameSettings.timeLimit },
            set: connection.updateTimeLimit
        )
    }

    private var topicBinding: Binding<WordTopic> {
        Binding(
            get: { connection.gameSettings.topic },
            set: connection.updateTopic
        )
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
