import Foundation

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
