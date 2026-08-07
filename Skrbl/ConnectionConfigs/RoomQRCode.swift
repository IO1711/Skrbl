//
//  RoomQRCode.swift
//  Sketra
//
//  Created by Codex on 30/07/2026.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum RoomQRCode {
    private static let context = CIContext()

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

    static func image(for roomID: UUID) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload(for: roomID).utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scaledImage = outputImage.transformed(
            by: CGAffineTransform(scaleX: 12, y: 12)
        )
        guard let cgImage = context.createCGImage(
            scaledImage,
            from: scaledImage.extent
        ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
