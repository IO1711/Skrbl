import Foundation
import Network

enum NearbyRoomEndpoint {
    case wifi(NWEndpoint)
    case bluetooth(UUID)
}
