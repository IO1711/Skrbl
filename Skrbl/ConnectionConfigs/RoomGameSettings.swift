import Foundation

struct RoomGameSettings: Codable, Equatable {
    let timeLimit: Int
    let topic: WordTopic
    let numberOfRounds: Int
}
