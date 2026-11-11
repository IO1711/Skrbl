import Foundation

struct WordDrop: Codable, Equatable, Identifiable {
    let id: UUID
    let playerName: String
    let text: String
    let horizontalPosition: Double
}
