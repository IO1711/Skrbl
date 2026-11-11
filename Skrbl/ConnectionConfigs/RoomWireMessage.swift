import Foundation

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
        case wordHint
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
    let playerScores: [RoomPlayerScore]?
    let wordHint: String?

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
        roundNumber: Int? = nil,
        playerScores: [RoomPlayerScore]? = nil,
        wordHint: String? = nil
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
        self.playerScores = playerScores
        self.wordHint = wordHint
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
        roundNumber: Int,
        playerScores: [RoomPlayerScore]
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .startGame,
            roomID: roomID,
            currentDrawerID: currentDrawerID,
            roundNumber: roundNumber,
            playerScores: playerScores
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
        remainingSeconds: Int,
        wordHint: String
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .roundStarted,
            roomID: roomID,
            currentDrawerID: currentDrawerID,
            remainingSeconds: remainingSeconds,
            wordHint: wordHint
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
        roundNumber: Int,
        playerScores: [RoomPlayerScore]
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .drawingTurn,
            roomID: roomID,
            currentDrawerID: currentDrawerID,
            roundNumber: roundNumber,
            playerScores: playerScores
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

    static func wordHint(
        roomID: UUID,
        wordHint: String
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .wordHint,
            roomID: roomID,
            wordHint: wordHint
        )
    }

    static func guessStatus(
        roomID: UUID,
        guessedPlayerIDs: [UUID],
        playerScores: [RoomPlayerScore]
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .guessStatus,
            roomID: roomID,
            guessedPlayerIDs: guessedPlayerIDs,
            playerScores: playerScores
        )
    }

    static func gameEnded(
        roomID: UUID,
        playerScores: [RoomPlayerScore]
    ) -> RoomWireMessage {
        RoomWireMessage(
            kind: .gameEnded,
            roomID: roomID,
            playerScores: playerScores
        )
    }
}
