//
//  CreateRoomView.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI

struct CreateRoomView: View {
    @Environment(\.dismiss) private var dismiss
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
            if connection.isShowingGameResults {
                GameResultsView(
                    rankings: connection.finalRankings,
                    onBackToRoom: connection.dismissGameResults
                )
            } else if connection.isGameStarted {
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
        .chalkBackButton(action: navigateBack)
        .edgeSwipeBack(
            isEnabled: !connection.isGameStarted,
            action: navigateBack
        )
        .onDisappear {
            connection.stop()
        }
    }

    private func roomForm(connectionMode: RoomConnectionMode) -> some View {
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
                //Section {

                    Text("Your Name")
                            .appTextStyle(AppTheme.secondaryChalkboardText(size: 20))

                    TextField("Player name", text: $playerName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .contentShape(Rectangle())
                        /*.background {
                         Image("input_frame")
                             .resizable()
                             .overlay {
                                 Image("monkey_chalk")
                                     .resizable()
                                     .frame(width: 108, height: 162)
                                     .offset(x:100, y: -40)
                             }
                        }*/
                        .overlay {
                            Image("input_frame")
                                .resizable()
                                .frame(width: 380)
                                .overlay {
                                    Image("monkey_chalk")
                                        .resizable()
                                        .frame(width: 108, height: 162)
                                        .offset(x:100, y: -40)
                                }
                                .allowsHitTesting(false)
                        }
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(createRoom)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    Text("The room will be created under this name.")
                            .appTextStyle(AppTheme.secondaryChalkboardText(size: 18))


                }/* header: {
                    Text("Your Name")
                        .appTextStyle(AppTheme.secondaryChalkboardText(size: 20))
                } footer: {
                    Text("The room will be created under this name.")
                        .appTextStyle(AppTheme.secondaryChalkboardText(size: 18))
                }*/

                Button(action: createRoom) {
                    Image("flat_button_frame")
                        .resizable()
                        .frame(maxWidth: 347)
                        .frame(height: 55)
                        .overlay {
                            Text("Create room")
                                .font(AppTheme.font(size: 18))
                                .foregroundStyle(AppTheme.text)
                        }
                }
                .frame(maxWidth: .infinity)
                .disabled(normalizedName.isEmpty)
                .opacity(normalizedName.isEmpty ? 0.45 : 1)

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

    private var navigationTitle: String {
        if connection.isShowingGameResults {
            return "Final Rankings"
        }
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

    private func navigateBack() {
        if connection.isShowingGameResults {
            connection.dismissGameResults()
        } else if connection.isGameStarted {
            dismiss()
        } else if hasCreatedRoom {
            connection.stop()
            hasCreatedRoom = false
            selectedConnectionMode = nil
        } else if selectedConnectionMode != nil {
            selectedConnectionMode = nil
        } else {
            dismiss()
        }
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



 Text("Your Name")
     .appTextStyle(AppTheme.secondaryChalkboardText(size: 20))

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

 Text("The room will be created under this name.")
     .appTextStyle(AppTheme.secondaryChalkboardText(size: 18))
 */
