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

    init(initialConnectionMode: RoomConnectionMode? = nil) {
        _selectedConnectionMode = State(initialValue: initialConnectionMode)
    }

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
        .chalkBackButton()
        .onDisappear {
            connection.stop()
        }
    }

    private func roomForm(connectionMode: RoomConnectionMode) -> some View {
        Form {
            Section {

                Text("Connection")
                    .appTextStyle(AppTheme.chalkboardText(size: 20))

                HStack {
                    //Label(connectionMode.title, systemImage: connectionMode.systemImage)
                    HStack {
                        Image("\(connectionMode.title)")
                            .resizable()
                            .frame(width: 44, height: 48)
                        
                        Text("\(connectionMode.title)")
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
                    //.buttonStyle(WhiteOutlineButtonStyle())
                }
            }
            .listRowBackground(Color.clear)

            Section {
                ZStack(alignment: .bottom) {
                        TextField("Player name", text: $playerName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background {
                                Image("input_frame")
                                    .resizable()
                            }
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit(createRoom)

                        Image("monkey_chalk")
                            .resizable()
                            .frame(width: 108, height: 162)
                            .offset(x: 100)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 162)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } header: {
                Text("Your Name")
                    .appTextStyle(AppTheme.secondaryChalkboardText(size: 20))
            } footer: {
                Text("The room will be created under this name.")
                    .appTextStyle(AppTheme.secondaryChalkboardText(size: 18))
            }
            .listRowBackground(Color.clear)

            Section {
                Button(action: createRoom) {
                    /*Label("Create Room", systemImage: "person.2.badge.plus")
                        .frame(maxWidth: .infinity)*/
                    Image("flat_button_frame")
                        .resizable()
                        .frame(width: 347, height: 55)
                        .overlay {
                            Text("Create room")
                                .font(AppTheme.font(size: 18))
                                .foregroundStyle(AppTheme.text)
                        }
                }
                //.buttonStyle(WhiteOutlineButtonStyle())
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
        return selectedConnectionMode == nil ? "" : "Create Room"
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

#Preview("Create Room") {
    NavigationStack {
        CreateRoomView(initialConnectionMode: .wifi)
    }
}


/*
 .textFieldStyle(.plain)
 .background(Color.clear)
 .textInputAutocapitalization(.words)
 .autocorrectionDisabled()
 .submitLabel(.go)
 .onSubmit(createRoom)
 .overlay {
     Image("input_frame")
         .resizable()
         .frame(width: 381, height: 60)
         .allowsHitTesting(false)
 }
 
 
 TextField("Player name", text: $playerName)
     .textFieldStyle(.plain)
     .padding(.horizontal, 24)
     .frame(maxWidth: .infinity)
     .frame(height: 60)
     .background {
         Image("input_frame")
             .resizable()
             .overlay {
                 Image("monkey_chalk")
                     .resizable()
                     .frame(width: 108, height: 162)
                     .offset(x:100, y: -40)
             }
     }
     .textInputAutocapitalization(.words)
     .autocorrectionDisabled()
     .submitLabel(.go)
     .onSubmit(createRoom)
     .listRowInsets(EdgeInsets())
     .listRowBackground(Color.clear)
     .listRowSeparator(.hidden)
 */
