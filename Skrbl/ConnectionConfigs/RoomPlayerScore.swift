import Foundation

struct RoomPlayerScore: Codable, Equatable, Identifiable {
    let playerID: UUID
    let playerName: String
    let points: Int

    var id: UUID {
        playerID
    }
}
