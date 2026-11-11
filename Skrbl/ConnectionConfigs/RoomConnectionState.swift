import Foundation

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
