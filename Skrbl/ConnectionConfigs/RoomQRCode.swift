//
//  RoomQRCode.swift
//  Sketra
//
//  Created by Codex on 30/07/2026.
//

import Foundation

enum RoomQRCode {
    static func payload(for roomID: UUID) -> String {
        var components = URLComponents()
        components.scheme = "sketra"
        components.host = "join"
        components.queryItems = [
            URLQueryItem(name: "room", value: roomID.uuidString)
        ]
        return components.string ?? "sketra://join?room=\(roomID.uuidString)"
    }

    static func roomID(from payload: String) -> UUID? {
        guard let components = URLComponents(string: payload),
              components.scheme?.lowercased() == "sketra",
              components.host?.lowercased() == "join",
              let roomValue = components.queryItems?.first(
                where: { $0.name == "room" }
              )?.value else {
            return nil
        }

        return UUID(uuidString: roomValue)
    }

}
