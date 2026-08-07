//
//  BluetoothRoomTransport.swift
//  Skrbl
//
//  Created by Codex on 31/07/2026.
//

@preconcurrency import CoreBluetooth
import Foundation

struct BluetoothDiscoveredRoom {
    let roomID: UUID
    let roomName: String
    let peripheralID: UUID
}

enum BluetoothRoomEvent {
    case hostReady
    case roomsChanged([BluetoothDiscoveredRoom])
    case peerConnected(UUID)
    case guestReady(UUID)
    case data(peerID: UUID, data: Data)
    case peerDisconnected(peerID: UUID, message: String)
    case failed(String)
}

@MainActor
final class BluetoothRoomTransport: NSObject {
    private enum Role {
        case idle
        case host
        case guest
    }

    private struct ChunkQueue {
        private(set) var chunks: [Data] = []
        private(set) var index = 0

        var current: Data? {
            index < chunks.count ? chunks[index] : nil
        }

        var isEmpty: Bool {
            current == nil
        }

        mutating func append(contentsOf newChunks: [Data]) {
            if index > 0 {
                chunks.removeFirst(index)
                index = 0
            }
            chunks.append(contentsOf: newChunks)
        }

        mutating func advance() {
            guard index < chunks.count else { return }
            index += 1
            if index == chunks.count {
                chunks.removeAll(keepingCapacity: true)
                index = 0
            }
        }
    }

    private static let serviceUUID = CBUUID(
        string: "32F17A2C-8471-4E27-9D15-6288446A7A31"
    )
    private static let receiveUUID = CBUUID(
        string: "32F17A2C-8471-4E27-9D15-6288446A7A32"
    )
    private static let notifyUUID = CBUUID(
        string: "32F17A2C-8471-4E27-9D15-6288446A7A33"
    )
    private static let roomIDSuffix = "-534B-4C42-8000-000000000000"
    private static let advertisementPrefix = "S"

    var eventHandler: ((BluetoothRoomEvent) -> Void)?

    private var role: Role = .idle
    private var pendingRoomID: UUID?
    private var pendingRoomName = ""
    private var peripheralManager: CBPeripheralManager?
    private var centralManager: CBCentralManager?
    private var receiveCharacteristic: CBMutableCharacteristic?
    private var notifyCharacteristic: CBMutableCharacteristic?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var discoveredRooms: [UUID: BluetoothDiscoveredRoom] = [:]
    private var targetPeripheralID: UUID?
    private var connectedPeripheral: CBPeripheral?
    private var guestReceiveCharacteristic: CBCharacteristic?
    private var guestNotifyCharacteristic: CBCharacteristic?
    private var guestWriteQueue = ChunkQueue()
    private var guestWriteInProgress = false
    private var guestReadyWasSent = false
    private var hostCentrals: [UUID: CBCentral] = [:]
    private var hostWriteQueues: [UUID: ChunkQueue] = [:]

    static func makeRoomID() -> UUID {
        let code = UInt32.random(in: UInt32.min...UInt32.max)
        let string = String(format: "%08X", code) + roomIDSuffix
        return UUID(uuidString: string)!
    }

    static func isBluetoothRoomID(_ roomID: UUID) -> Bool {
        roomID.uuidString.uppercased().hasSuffix(roomIDSuffix)
    }

    func startHosting(roomID: UUID, roomName: String) {
        stop()
        role = .host
        pendingRoomID = roomID
        pendingRoomName = roomName
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func startSearching() {
        stop()
        role = .guest
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func join(peripheralID: UUID) {
        guard role == .guest,
              let peripheral = discoveredPeripherals[peripheralID],
              let centralManager else {
            eventHandler?(.failed("The Bluetooth room is no longer available."))
            return
        }

        targetPeripheralID = peripheralID
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }

    func send(_ data: Data, to peerID: UUID) {
        switch role {
        case .host:
            enqueueHostData(data, peerID: peerID)
        case .guest:
            guard connectedPeripheral?.identifier == peerID else { return }
            enqueueGuestData(data)
        case .idle:
            break
        }
    }

    func disconnect(peerID: UUID) {
        switch role {
        case .host:
            hostCentrals[peerID] = nil
            hostWriteQueues[peerID] = nil
        case .guest:
            guard connectedPeripheral?.identifier == peerID,
                  let connectedPeripheral else {
                return
            }
            centralManager?.cancelPeripheralConnection(connectedPeripheral)
        case .idle:
            break
        }
    }

    func stop() {
        role = .idle
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        centralManager?.stopScan()
        if let connectedPeripheral {
            centralManager?.cancelPeripheralConnection(connectedPeripheral)
            connectedPeripheral.delegate = nil
        }
        peripheralManager?.delegate = nil
        centralManager?.delegate = nil
        peripheralManager = nil
        centralManager = nil
        receiveCharacteristic = nil
        notifyCharacteristic = nil
        discoveredPeripherals.removeAll()
        discoveredRooms.removeAll()
        targetPeripheralID = nil
        connectedPeripheral = nil
        guestReceiveCharacteristic = nil
        guestNotifyCharacteristic = nil
        guestWriteQueue = ChunkQueue()
        guestWriteInProgress = false
        guestReadyWasSent = false
        hostCentrals.removeAll()
        hostWriteQueues.removeAll()
        pendingRoomID = nil
        pendingRoomName = ""
    }

    private func configureHostService() {
        guard role == .host,
              receiveCharacteristic == nil,
              notifyCharacteristic == nil,
              let peripheralManager else {
            return
        }

        let receiveCharacteristic = CBMutableCharacteristic(
            type: Self.receiveUUID,
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )
        let notifyCharacteristic = CBMutableCharacteristic(
            type: Self.notifyUUID,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [receiveCharacteristic, notifyCharacteristic]
        self.receiveCharacteristic = receiveCharacteristic
        self.notifyCharacteristic = notifyCharacteristic
        peripheralManager.add(service)
    }

    private func startAdvertising() {
        guard role == .host,
              let roomID = pendingRoomID,
              let peripheralManager else {
            return
        }

        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: Self.advertisementName(
                roomID: roomID,
                roomName: pendingRoomName
            )
        ])
    }

    private static func advertisementName(
        roomID: UUID,
        roomName: String
    ) -> String {
        let roomCode = String(roomID.uuidString.prefix(8)).uppercased()
        let hostName = roomName
            .replacingOccurrences(of: "’s Room", with: "")
            .unicodeScalars
            .filter {
                $0.value < 128
                    && (CharacterSet.alphanumerics.contains($0) || $0 == " ")
            }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shortHostName = String((hostName.isEmpty ? "Host" : hostName).prefix(14))
        return "\(advertisementPrefix)|\(roomCode)|\(shortHostName)"
    }

    private static func discoveredRoom(
        advertisementName: String,
        peripheralID: UUID
    ) -> BluetoothDiscoveredRoom? {
        let parts = advertisementName.split(
            separator: "|",
            maxSplits: 2,
            omittingEmptySubsequences: false
        )
        guard parts.count == 3,
              parts[0] == Substring(advertisementPrefix),
              parts[1].count == 8,
              let roomID = UUID(
                uuidString: String(parts[1]).uppercased() + roomIDSuffix
              ) else {
            return nil
        }

        let hostName = parts[2].isEmpty ? "Bluetooth Host" : String(parts[2])
        return BluetoothDiscoveredRoom(
            roomID: roomID,
            roomName: "\(hostName)’s Room",
            peripheralID: peripheralID
        )
    }

    private func enqueueGuestData(_ data: Data) {
        guard let connectedPeripheral else { return }
        let maximumLength = max(
            connectedPeripheral.maximumWriteValueLength(for: .withResponse),
            20
        )
        guestWriteQueue.append(
            contentsOf: Self.chunks(of: data, maximumLength: maximumLength)
        )
        drainGuestWriteQueue()
    }

    private func drainGuestWriteQueue() {
        guard !guestWriteInProgress,
              let connectedPeripheral,
              let guestReceiveCharacteristic,
              let chunk = guestWriteQueue.current else {
            return
        }

        guestWriteInProgress = true
        connectedPeripheral.writeValue(
            chunk,
            for: guestReceiveCharacteristic,
            type: .withResponse
        )
    }

    private func enqueueHostData(_ data: Data, peerID: UUID) {
        guard let central = hostCentrals[peerID] else { return }
        let maximumLength = max(central.maximumUpdateValueLength, 20)
        var queue = hostWriteQueues[peerID] ?? ChunkQueue()
        queue.append(
            contentsOf: Self.chunks(of: data, maximumLength: maximumLength)
        )
        hostWriteQueues[peerID] = queue
        drainHostWriteQueue(peerID: peerID)
    }

    private func drainHostWriteQueue(peerID: UUID) {
        guard let peripheralManager,
              let notifyCharacteristic,
              let central = hostCentrals[peerID],
              var queue = hostWriteQueues[peerID] else {
            return
        }

        while let chunk = queue.current {
            guard peripheralManager.updateValue(
                chunk,
                for: notifyCharacteristic,
                onSubscribedCentrals: [central]
            ) else {
                hostWriteQueues[peerID] = queue
                return
            }
            queue.advance()
        }

        hostWriteQueues[peerID] = nil
    }

    private static func chunks(
        of data: Data,
        maximumLength: Int
    ) -> [Data] {
        guard !data.isEmpty else { return [] }

        var chunks: [Data] = []
        var start = data.startIndex
        while start < data.endIndex {
            let end = data.index(
                start,
                offsetBy: maximumLength,
                limitedBy: data.endIndex
            ) ?? data.endIndex
            chunks.append(data.subdata(in: start..<end))
            start = end
        }
        return chunks
    }

    private func reportBluetoothState(_ state: CBManagerState) {
        switch state {
        case .poweredOff:
            eventHandler?(.failed("Turn on Bluetooth to continue."))
        case .unauthorized:
            eventHandler?(.failed("Bluetooth access was not allowed."))
        case .unsupported:
            eventHandler?(.failed("Bluetooth is not supported on this device."))
        case .resetting:
            eventHandler?(.failed("Bluetooth is restarting. Try again shortly."))
        case .unknown, .poweredOn:
            break
        @unknown default:
            eventHandler?(.failed("Bluetooth is unavailable."))
        }
    }
}

extension BluetoothRoomTransport: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard role == .host else { return }

        if peripheral.state == .poweredOn {
            configureHostService()
        } else {
            reportBluetoothState(peripheral.state)
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: (any Error)?
    ) {
        guard role == .host else { return }

        if let error {
            eventHandler?(.failed("Could not create the Bluetooth room: \(error.localizedDescription)"))
        } else {
            startAdvertising()
        }
    }

    func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: (any Error)?
    ) {
        guard role == .host else { return }

        if let error {
            eventHandler?(.failed("Bluetooth advertising failed: \(error.localizedDescription)"))
        } else {
            eventHandler?(.hostReady)
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard role == .host,
              characteristic.uuid == Self.notifyUUID else {
            return
        }

        let peerID = central.identifier
        let isNewPeer = hostCentrals[peerID] == nil
        hostCentrals[peerID] = central
        if isNewPeer {
            hostWriteQueues[peerID] = ChunkQueue()
            eventHandler?(.peerConnected(peerID))
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        guard role == .host else { return }

        let peerID = central.identifier
        hostCentrals[peerID] = nil
        hostWriteQueues[peerID] = nil
        eventHandler?(
            .peerDisconnected(
                peerID: peerID,
                message: "The Bluetooth connection was closed."
            )
        )
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        guard role == .host else { return }

        for request in requests {
            guard request.characteristic.uuid == Self.receiveUUID,
                  let value = request.value else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }

            peripheral.respond(to: request, withResult: .success)
            eventHandler?(
                .data(
                    peerID: request.central.identifier,
                    data: value
                )
            )
        }
    }

    func peripheralManagerIsReady(
        toUpdateSubscribers peripheral: CBPeripheralManager
    ) {
        for peerID in hostCentrals.keys {
            drainHostWriteQueue(peerID: peerID)
        }
    }
}

extension BluetoothRoomTransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard role == .guest else { return }

        if central.state == .poweredOn {
            central.scanForPeripherals(
                withServices: [Self.serviceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        } else {
            reportBluetoothState(central.state)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard role == .guest,
              let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey]
                as? String ?? peripheral.name,
              let room = Self.discoveredRoom(
                advertisementName: advertisedName,
                peripheralID: peripheral.identifier
              ) else {
            return
        }

        discoveredPeripherals[peripheral.identifier] = peripheral
        discoveredRooms[peripheral.identifier] = room
        eventHandler?(
            .roomsChanged(
                discoveredRooms.values.sorted {
                    $0.roomName.localizedCaseInsensitiveCompare($1.roomName)
                        == .orderedAscending
                }
            )
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        guard role == .guest,
              peripheral.identifier == targetPeripheralID else {
            return
        }

        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        guard role == .guest else { return }

        eventHandler?(
            .failed(
                "Could not join the Bluetooth room: "
                    + (error?.localizedDescription ?? "Connection failed.")
            )
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        guard role == .guest else { return }

        eventHandler?(
            .peerDisconnected(
                peerID: peripheral.identifier,
                message: error?.localizedDescription
                    ?? "The Bluetooth connection was closed."
            )
        )
    }
}

extension BluetoothRoomTransport: CBPeripheralDelegate {
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: (any Error)?
    ) {
        guard role == .guest else { return }

        if let error {
            eventHandler?(.failed("Bluetooth service discovery failed: \(error.localizedDescription)"))
            return
        }

        guard let service = peripheral.services?.first(
            where: { $0.uuid == Self.serviceUUID }
        ) else {
            eventHandler?(.failed("This device is not advertising a Skrbl room."))
            return
        }

        peripheral.discoverCharacteristics(
            [Self.receiveUUID, Self.notifyUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        guard role == .guest else { return }

        if let error {
            eventHandler?(.failed("Bluetooth setup failed: \(error.localizedDescription)"))
            return
        }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == Self.receiveUUID {
                guestReceiveCharacteristic = characteristic
            } else if characteristic.uuid == Self.notifyUUID {
                guestNotifyCharacteristic = characteristic
            }
        }

        guard guestReceiveCharacteristic != nil,
              let guestNotifyCharacteristic else {
            eventHandler?(.failed("The Bluetooth room has an incompatible protocol."))
            return
        }

        peripheral.setNotifyValue(true, for: guestNotifyCharacteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard role == .guest,
              characteristic.uuid == Self.notifyUUID else {
            return
        }

        if let error {
            eventHandler?(.failed("Bluetooth notifications failed: \(error.localizedDescription)"))
        } else if characteristic.isNotifying,
                  !guestReadyWasSent {
            guestReadyWasSent = true
            eventHandler?(.guestReady(peripheral.identifier))
            drainGuestWriteQueue()
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard role == .guest,
              characteristic.uuid == Self.notifyUUID else {
            return
        }

        if let error {
            eventHandler?(.failed("Bluetooth receive failed: \(error.localizedDescription)"))
        } else if let data = characteristic.value,
                  !data.isEmpty {
            eventHandler?(.data(peerID: peripheral.identifier, data: data))
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard role == .guest,
              characteristic.uuid == Self.receiveUUID else {
            return
        }

        guestWriteInProgress = false
        if let error {
            eventHandler?(.failed("Bluetooth send failed: \(error.localizedDescription)"))
            return
        }

        guestWriteQueue.advance()
        drainGuestWriteQueue()
    }
}
