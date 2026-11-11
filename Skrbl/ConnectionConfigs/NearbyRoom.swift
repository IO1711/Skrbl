import Foundation

struct NearbyRoom: Identifiable {
    let roomID: UUID
    let roomName: String
    let endpoint: NearbyRoomEndpoint

    var id: UUID {
        roomID
    }
}
