import Foundation
import Testing
@testable import Skrbl

@MainActor
struct RoomLogicTests {
    @Test func qrPayloadRoundTrips() {
        let roomID = UUID()
        #expect(RoomQRCode.roomID(from: RoomQRCode.payload(for: roomID)) == roomID)
        #expect(RoomQRCode.roomID(from: "https://join?room=\(roomID)") == nil)
        #expect(RoomQRCode.roomID(from: "sketra://other?room=\(roomID)") == nil)
        #expect(RoomQRCode.roomID(from: "sketra://join?room=invalid") == nil)
    }

    @Test func playerNamesAreTrimmedAndLimited() {
        #expect(RoomGameRules.normalizedPlayerName(" \n Alex \t") == "Alex")
        #expect(RoomGameRules.normalizedPlayerName(" \n ").isEmpty)
        let longName = String(repeating: "👩🏽‍🎨", count: 30)
        #expect(RoomGameRules.normalizedPlayerName(longName).count == 24)
        #expect(RoomGameRules.normalizedViewerWord(" a\n b\t c ") == "a b c")
        #expect(RoomGameRules.normalizedViewerWord(String(repeating: "a", count: 60)).count == 32)
    }

    @Test func scoringDropsAsTimeExpires() {
        let scores = stride(from: 60, through: 0, by: -1).map {
            RoomGameRules.correctGuessPoints(remainingSeconds: $0, timeLimit: 60)
        }
        #expect(scores.first == 100)
        #expect(scores.last == 20)
        #expect(zip(scores, scores.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(RoomGameRules.correctGuessPoints(remainingSeconds: 70, timeLimit: 60) == 100)
        #expect(RoomGameRules.correctGuessPoints(remainingSeconds: -10, timeLimit: 60) == 20)
        #expect(RoomGameRules.correctGuessPoints(remainingSeconds: 10, timeLimit: 0) == 20)
    }

    @Test func hintsPreserveWordBoundariesAndLimitPenalties() {
        let characters = Array("Café cat!")
        #expect(RoomGameRules.wordHint(characters: characters, revealedIndices: []) == "_ _ _ _   _ _ _ !")
        #expect(RoomGameRules.wordHint(characters: characters, revealedIndices: [0, 3]) == "C _ _ é   _ _ _ !")
        #expect(RoomGameRules.guessKey(" CAFÉ-cat! ") == "cafecat")
        #expect(RoomGameRules.pointsAfterHintPenalty(100, revealedLetterCount: 1) == 90)
        #expect(RoomGameRules.pointsAfterHintPenalty(100, revealedLetterCount: 20) == 50)
    }

    @Test func disconnectedDrawerAdvancesTheTurn() throws {
        let players = [UUID(), UUID(), UUID()]
        let turn = try #require(RoomGameRules.nextTurn(
            after: players[1],
            previousOrder: players,
            activePlayerIDs: [players[0], players[2]],
            round: 1,
            numberOfRounds: 3
        ))
        #expect(turn.drawerID == players[2])
        #expect(turn.round == 1)
    }

    @Test func turnWrapsAndFinalRoundEnds() throws {
        let players = [UUID(), UUID(), UUID()]
        let turn = try #require(RoomGameRules.nextTurn(
            after: players[2], previousOrder: players,
            activePlayerIDs: [players[0], players[1]], round: 1, numberOfRounds: 2
        ))
        #expect(turn.drawerID == players[0])
        #expect(turn.round == 2)
        #expect(RoomGameRules.nextTurn(
            after: players[2], previousOrder: players,
            activePlayerIDs: [players[0]], round: 2, numberOfRounds: 2
        ) == nil)
        #expect(RoomGameRules.nextTurn(
            after: players[0], previousOrder: players,
            activePlayerIDs: [], round: 1, numberOfRounds: 2
        ) == nil)
    }
}
