import Foundation
import Testing
@testable import Skrbl

@MainActor
struct RoomWireCodecTests {
    @Test func fragmentedAndCoalescedPacketsDecodeInOrder() throws {
        let roomID = UUID()
        let first = try RoomWireCodec.packet(for: .join(
            roomID: roomID, playerID: UUID(), playerName: "Alex"
        ))
        let second = try RoomWireCodec.packet(for: .skipTurn(
            roomID: roomID, playerID: UUID()
        ))
        var buffer = Data(first.prefix(2))
        #expect(try RoomWireCodec.nextMessage(in: &buffer) == nil)
        buffer.append(first.dropFirst(2).prefix(3))
        #expect(try RoomWireCodec.nextMessage(in: &buffer) == nil)
        buffer.append(first.dropFirst(5))
        buffer.append(second)
        #expect(try RoomWireCodec.nextMessage(in: &buffer)?.kind == .join)
        #expect(try RoomWireCodec.nextMessage(in: &buffer)?.kind == .skipTurn)
        #expect(buffer.isEmpty)
    }

    @Test func malformedWireMessagesAreRejected() {
        var zeroLength = Data([0, 0, 0, 0])
        #expect(throws: RoomWireCodec.Failure.self) {
            try RoomWireCodec.nextMessage(in: &zeroLength)
        }
        var oversized = Data([0, 16, 0, 1])
        #expect(throws: RoomWireCodec.Failure.self) {
            try RoomWireCodec.nextMessage(in: &oversized)
        }
        var invalidJSON = Data([0, 0, 0, 1, 0x7B])
        #expect(throws: DecodingError.self) {
            try RoomWireCodec.nextMessage(in: &invalidJSON)
        }
    }

    @Test func invalidDrawingIsRejectedBeforeApplication() throws {
        let command = try JSONDecoder().decode(
            SketchCommand.self,
            from: Data(#"{"action":"beginStroke","point":{"x":2,"y":0.5},"color":"black"}"#.utf8)
        )
        var packet = try RoomWireCodec.packet(for: .drawing(
            roomID: UUID(), playerID: UUID(), command: command
        ))
        #expect(throws: RoomWireCodec.Failure.self) {
            try RoomWireCodec.nextMessage(in: &packet)
        }
    }
}
