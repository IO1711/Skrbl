import Foundation

enum RoomWireCodec {
    static let maximumMessageSize = 1_048_576

    enum Failure: Error {
        case invalidLength
        case invalidDrawing
    }

    static func packet(for message: RoomWireMessage) throws -> Data {
        let payload = try JSONEncoder().encode(message)
        guard !payload.isEmpty, payload.count <= maximumMessageSize else {
            throw Failure.invalidLength
        }
        var length = UInt32(payload.count).bigEndian
        var packet = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        packet.append(payload)
        return packet
    }

    /// Returns nil for an incomplete frame; malformed complete frames throw.
    static func nextMessage(in buffer: inout Data) throws -> RoomWireMessage? {
        let headerSize = MemoryLayout<UInt32>.size
        guard buffer.count >= headerSize else { return nil }
        let payloadStart = buffer.index(buffer.startIndex, offsetBy: headerSize)
        let length = buffer[..<payloadStart].reduce(UInt32(0)) {
            ($0 << 8) | UInt32($1)
        }
        guard length > 0, Int(length) <= maximumMessageSize else {
            throw Failure.invalidLength
        }
        let totalLength = headerSize + Int(length)
        guard buffer.count >= totalLength else { return nil }
        let end = buffer.index(buffer.startIndex, offsetBy: totalLength)
        let message = try JSONDecoder().decode(
            RoomWireMessage.self,
            from: buffer.subdata(in: payloadStart..<end)
        )
        if message.kind == .drawing {
            guard message.drawingCommand?.isValid() == true else {
                throw Failure.invalidDrawing
            }
        }
        buffer = Data(buffer[end...])
        return message
    }
}
