//
//  RoomModels.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import Foundation
import Network

enum RoomConnectionMode: String, CaseIterable, Identifiable {
    case wifi
    case bluetooth

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .wifi:
            "Wi-Fi"
        case .bluetooth:
            "Bluetooth"
        }
    }

    var systemImage: String {
        switch self {
        case .wifi:
            "wifi"
        case .bluetooth:
            "dot.radiowaves.left.and.right"
        }
    }

    var description: String {
        switch self {
        case .wifi:
            "Use the same network or a direct peer-to-peer Wi-Fi connection."
        case .bluetooth:
            "Discover and join nearby devices using Bluetooth Low Energy."
        }
    }
}

enum NearbyRoomEndpoint {
    case wifi(NWEndpoint)
    case bluetooth(UUID)
}

struct NearbyRoom: Identifiable {
    let roomID: UUID
    let roomName: String
    let endpoint: NearbyRoomEndpoint

    var id: UUID {
        roomID
    }
}

enum RoomConnectionState: Equatable {
    case idle
    case hosting
    case searching
    case waitingForScannedRoom
    case connecting
    case connected
    case failed(String)

    var statusText: String {
        switch self {
        case .idle:
            "Preparing…"
        case .hosting:
            "Room is open to nearby players"
        case .searching:
            "Looking for nearby rooms…"
        case .waitingForScannedRoom:
            "Looking for the scanned room…"
        case .connecting:
            "Joining room…"
        case .connected:
            "Connected"
        case .failed(let message):
            message
        }
    }
}

enum RoomGamePhase: String, Codable {
    case lobby
    case choosingWord
    case drawing
}

struct RoomGameSettings: Codable, Equatable {
    let timeLimit: Int
    let topic: WordTopic
    let numberOfRounds: Int
}

struct WordDrop: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let horizontalPosition: Double
}

struct RoomWireMessage: Codable {
    enum Kind: String, Codable {
        case join
        case roster
        case settings
        case startGame
        case wordChoices
        case selectWord
        case roundStarted
        case drawing
        case drawingTurn
        case skipTurn
        case wordDrop
        case guessStatus
        case gameEnded
    }

    let kind: Kind
    let roomID: UUID
    let playerID: UUID?
    let playerName: String?
    let roomName: String?
    let players: [String]?
    let playerIDs: [UUID]?
    let currentDrawerID: UUID?
    let drawingCommand: SketchCommand?
    let wordDrop: WordDrop?
    let settings: RoomGameSettings?
    let wordChoices: [String]?
    let selectedWord: String?
    let remainingSeconds: Int?
    let guessedPlayerIDs: [UUID]?
    let roundNumber: Int?

    private init(
        kind: Kind,
        roomID: UUID,
        playerID: UUID? = nil,
        playerName: String? = nil,
        roomName: String? = nil,
        players: [String]? = nil,
        playerIDs: [UUID]? = nil,
        currentDrawerID: UUID? = nil,
        drawingCommand: SketchCommand? = nil,
        wordDrop: WordDrop? = nil,
        settings: RoomGameSettings? = nil,
        wordChoices: [String]? = nil,
        selectedWord: String? = nil,
        remainingSeconds: Int? = nil,
        guessedPlayerIDs: [UUID]? = nil,
        roundNumber: Int? = nil
    ) {
        self.kind = kind
        self.roomID = roomID
        self.playerID = playerID
        self.playerName = playerName
        self.roomName = roomName
        self.players = players
        self.playerIDs = playerIDs
        self.currentDrawerID = currentDrawerID
        self.drawingCommand = drawingCommand
        self.wordDrop = wordDrop
        self.settings = settings
        self.wordChoices = wordChoices
        self.selectedWord = selectedWord
        self.remainingSeconds = remainingSeconds
        self.guessedPlayerIDs = guessedPlayerIDs
        self.roundNumber = roundNumber
    }

    static func join(
        roomID: UUID,
        playerID: UUID,
        playerName: String
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .join,
            roomID: roomID,
            playerID: playerID,
            playerName: playerName
        )
    }

    static func roster(
        roomID: UUID,
        roomName: String,
        players: [String],
        playerIDs: [UUID]
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .roster,
            roomID: roomID,
            roomName: roomName,
            players: players,
            playerIDs: playerIDs
        )
    }

    static func settings(
        roomID: UUID,
        settings: RoomGameSettings
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .settings,
            roomID: roomID,
            settings: settings
        )
    }

    static func startGame(
        roomID: UUID,
        currentDrawerID: UUID,
        roundNumber: Int
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .startGame,
            roomID: roomID,
            currentDrawerID: currentDrawerID,
            roundNumber: roundNumber
        )
    }

    static func wordChoices(
        roomID: UUID,
        currentDrawerID: UUID,
        choices: [String]
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .wordChoices,
            roomID: roomID,
            currentDrawerID: currentDrawerID,
            wordChoices: choices
        )
    }

    static func selectWord(
        roomID: UUID,
        playerID: UUID,
        word: String
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .selectWord,
            roomID: roomID,
            playerID: playerID,
            selectedWord: word
        )
    }

    static func roundStarted(
        roomID: UUID,
        currentDrawerID: UUID,
        remainingSeconds: Int
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .roundStarted,
            roomID: roomID,
            currentDrawerID: currentDrawerID,
            remainingSeconds: remainingSeconds
        )
    }

    static func drawing(
        roomID: UUID,
        playerID: UUID,
        command: SketchCommand
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .drawing,
            roomID: roomID,
            playerID: playerID,
            drawingCommand: command
        )
    }

    static func drawingTurn(
        roomID: UUID,
        currentDrawerID: UUID,
        roundNumber: Int
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .drawingTurn,
            roomID: roomID,
            currentDrawerID: currentDrawerID,
            roundNumber: roundNumber
        )
    }

    static func skipTurn(
        roomID: UUID,
        playerID: UUID
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .skipTurn,
            roomID: roomID,
            playerID: playerID
        )
    }

    static func wordDrop(
        roomID: UUID,
        playerID: UUID,
        wordDrop: WordDrop
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .wordDrop,
            roomID: roomID,
            playerID: playerID,
            wordDrop: wordDrop
        )
    }

    static func guessStatus(
        roomID: UUID,
        guessedPlayerIDs: [UUID]
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .guessStatus,
            roomID: roomID,
            guessedPlayerIDs: guessedPlayerIDs
        )
    }

    static func gameEnded(roomID: UUID) -> RoomWireMessage {
        RoomWireMessage(
            kind: .gameEnded,
            roomID: roomID
        )
    }
}
