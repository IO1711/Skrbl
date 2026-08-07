//
//  RoomConnectionManager.swift
//  Skrbl
//
//  Created by Codex on 30/07/2026.
//

import Combine
import Foundation
@preconcurrency import Network

@MainActor
final class RoomConnectionManager: ObservableObject {
    static let bonjourServiceType = "_sketra-room._tcp"

    static let availableTimeLimits = [30, 60, 90, 120, 240]
    static let defaultGameSettings = RoomGameSettings(
        timeLimit: 60,
        topic: .animals,
        numberOfRounds: 5
    )

    @Published private(set) var state: RoomConnectionState = .idle
    @Published private(set) var nearbyRooms: [NearbyRoom] = []
    @Published private(set) var players: [String] = []
    @Published private(set) var roomID: UUID?
    @Published private(set) var roomName = ""
    @Published private(set) var isGameStarted = false
    @Published private(set) var playerIDs: [UUID] = []
    @Published private(set) var currentDrawerID: UUID?
    @Published private(set) var connectionMode: RoomConnectionMode?
    @Published private(set) var activeWordDrops: [WordDrop] = []
    @Published private(set) var gameSettings = defaultGameSettings
    @Published private(set) var gamePhase: RoomGamePhase = .lobby
    @Published private(set) var wordChoices: [String] = []
    @Published private(set) var wordToDraw: String?
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var currentRound = 0
    @Published private(set) var guessedPlayerIDs: Set<UUID> = []

    let sketchTools = SketchTools()

    private enum Mode: Equatable {
        case idle
        case host
        case guest
    }

    private enum TransportPeer: Hashable {
        case wifi(ObjectIdentifier)
        case bluetooth(UUID)
    }

    private static let maximumMessageSize: UInt32 = 1_048_576

    private let networkQueue = DispatchQueue(
        label: "com.bestAppleDev.Skrbl.room-network",
        qos: .userInitiated
    )
    private let bluetoothTransport = BluetoothRoomTransport()

    private var mode: Mode = .idle
    private var localPlayerID = UUID()
    private var localPlayerName = ""
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var clientConnection: NWConnection?
    private var hostConnections: [ObjectIdentifier: NWConnection] = [:]
    private var hostPeers: Set<TransportPeer> = []
    private var clientPeer: TransportPeer?
    private var playerNamesByPeer: [TransportPeer: String] = [:]
    private var playerIDsByPeer: [TransportPeer: UUID] = [:]
    private var receiveBuffers: [TransportPeer: Data] = [:]
    private var scannedRoomID: UUID?
    private var generation = 0
    private var pendingWordChoices: [String] = []
    private var currentSecretWord: String?
    private var roundTimerTask: Task<Void, Never>?
    private var gamePlayerIDs: [UUID] = []

    var isConnected: Bool {
        state == .connected
    }

    var canDraw: Bool {
        isGameStarted
            && gamePhase == .drawing
            && currentDrawerID == localPlayerID
    }

    var canSubmitWord: Bool {
        isGameStarted
            && gamePhase == .drawing
            && currentDrawerID != nil
            && currentDrawerID != localPlayerID
            && !guessedPlayerIDs.contains(localPlayerID)
    }

    var isChoosingWord: Bool {
        isGameStarted
            && gamePhase == .choosingWord
            && currentDrawerID == localPlayerID
    }

    var localPlayerHasGuessed: Bool {
        guessedPlayerIDs.contains(localPlayerID)
    }

    var currentDrawerName: String? {
        guard let currentDrawerID,
              let index = playerIDs.firstIndex(of: currentDrawerID),
              players.indices.contains(index) else {
            return nil
        }

        return players[index]
    }

    func hasGuessed(playerID: UUID) -> Bool {
        guessedPlayerIDs.contains(playerID)
    }

    init() {
        sketchTools.commandHandler = { [weak self] command in
            self?.sendLocalDrawing(command)
        }
        bluetoothTransport.eventHandler = { [weak self] event in
            self?.handleBluetoothEvent(event)
        }
    }

    @discardableResult
    func createRoom(
        playerName: String,
        connectionMode: RoomConnectionMode
    ) -> Bool {
        let playerName = Self.normalizedPlayerName(playerName)
        guard !playerName.isEmpty else { return false }

        stopTransport()
        resetGameplayState()
        gameSettings = Self.defaultGameSettings
        self.connectionMode = connectionMode

        localPlayerID = UUID()
        let newRoomID = connectionMode == .bluetooth
            ? BluetoothRoomTransport.makeRoomID()
            : UUID()
        let newRoomName = "\(playerName)’s Room"
        localPlayerName = playerName
        roomID = newRoomID
        roomName = newRoomName
        players = [playerName]
        playerIDs = [localPlayerID]
        mode = .host

        switch connectionMode {
        case .wifi:
            state = .hosting
            return startWiFiHosting(
                roomID: newRoomID,
                roomName: newRoomName
            )
        case .bluetooth:
            state = .idle
            bluetoothTransport.startHosting(
                roomID: newRoomID,
                roomName: newRoomName
            )
            return true
        }
    }

    func startSearching(
        playerName: String,
        connectionMode: RoomConnectionMode
    ) {
        let playerName = Self.normalizedPlayerName(playerName)
        guard !playerName.isEmpty else { return }

        stopTransport()
        resetGameplayState()
        gameSettings = Self.defaultGameSettings
        self.connectionMode = connectionMode

        localPlayerID = UUID()
        localPlayerName = playerName
        players = [playerName]
        playerIDs = [localPlayerID]
        mode = .guest
        state = .searching

        switch connectionMode {
        case .wifi:
            startWiFiSearch()
        case .bluetooth:
            bluetoothTransport.startSearching()
        }
    }

    func join(_ room: NearbyRoom) {
        guard mode == .guest,
              state != .connecting,
              !isConnected,
              clientPeer == nil else {
            return
        }

        scannedRoomID = nil
        nearbyRooms = []
        roomID = room.roomID
        roomName = room.roomName
        state = .connecting

        switch room.endpoint {
        case .wifi(let endpoint):
            guard connectionMode == .wifi else { return }
            browser?.cancel()
            browser = nil

            let connection = NWConnection(
                to: endpoint,
                using: Self.networkParameters()
            )
            clientConnection = connection
            configure(
                connection,
                isHostConnection: false,
                generation: generation
            )
            connection.start(queue: networkQueue)
        case .bluetooth(let peripheralID):
            guard connectionMode == .bluetooth else { return }
            bluetoothTransport.join(peripheralID: peripheralID)
        }
    }

    func joinRoom(withID roomID: UUID) {
        guard mode == .guest,
              let connectionMode else {
            return
        }

        let isBluetoothRoom = BluetoothRoomTransport.isBluetoothRoomID(roomID)
        if connectionMode == .wifi, isBluetoothRoom {
            state = .failed("This QR code belongs to a Bluetooth room. Select Bluetooth to join it.")
            return
        }
        if connectionMode == .bluetooth, !isBluetoothRoom {
            state = .failed("This QR code belongs to a Wi-Fi room. Select Wi-Fi to join it.")
            return
        }

        if let room = nearbyRooms.first(where: { $0.roomID == roomID }) {
            join(room)
            return
        }

        scannedRoomID = roomID
        state = .waitingForScannedRoom
    }

    func updateTimeLimit(_ timeLimit: Int) {
        guard mode == .host,
              !isGameStarted,
              Self.availableTimeLimits.contains(timeLimit) else {
            return
        }

        gameSettings = RoomGameSettings(
            timeLimit: timeLimit,
            topic: gameSettings.topic,
            numberOfRounds: gameSettings.numberOfRounds
        )
        broadcastSettings()
    }

    func updateTopic(_ topic: WordTopic) {
        guard mode == .host,
              !isGameStarted else {
            return
        }

        gameSettings = RoomGameSettings(
            timeLimit: gameSettings.timeLimit,
            topic: topic,
            numberOfRounds: gameSettings.numberOfRounds
        )
        broadcastSettings()
    }

    func updateNumberOfRounds(_ numberOfRounds: Int) {
        guard mode == .host,
              !isGameStarted,
              numberOfRounds >= 1 else {
            return
        }

        gameSettings = RoomGameSettings(
            timeLimit: gameSettings.timeLimit,
            topic: gameSettings.topic,
            numberOfRounds: numberOfRounds
        )
        broadcastSettings()
    }

    func startGame() {
        guard mode == .host,
              players.count >= 2,
              !isGameStarted,
              let firstDrawerID = playerIDs.first else {
            return
        }

        do {
            let choices = try WordLibrary.choices(for: gameSettings.topic)
            gamePlayerIDs = playerIDs
            currentRound = 1
            isGameStarted = true
            beginTurn(
                drawerID: firstDrawerID,
                choices: choices,
                isInitialTurn: true
            )
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func selectWord(_ word: String) {
        guard isChoosingWord,
              wordChoices.contains(word),
              let roomID else {
            return
        }

        switch mode {
        case .host:
            beginDrawingRound(with: word)
        case .guest:
            guard let clientPeer else { return }
            wordToDraw = word
            wordChoices = []
            send(
                .selectWord(
                    roomID: roomID,
                    playerID: localPlayerID,
                    word: word
                ),
                through: clientPeer
            )
        case .idle:
            break
        }
    }

    func skipTurn() {
        guard canDraw,
              let roomID else {
            return
        }

        switch mode {
        case .host:
            finishRound()
        case .guest:
            guard let clientPeer else { return }
            send(
                .skipTurn(
                    roomID: roomID,
                    playerID: localPlayerID
                ),
                through: clientPeer
            )
            roundTimerTask?.cancel()
            roundTimerTask = nil
            gamePhase = .choosingWord
            remainingSeconds = 0
            wordToDraw = nil
        case .idle:
            break
        }
    }

    @discardableResult
    func sendWord(_ word: String) -> Bool {
        guard canSubmitWord,
              let roomID else {
            return false
        }

        let normalizedWord = Self.normalizedViewerWord(word)
        guard !normalizedWord.isEmpty else { return false }

        let wordDrop = WordDrop(
            id: UUID(),
            text: normalizedWord,
            horizontalPosition: Double.random(in: 0.12...0.88)
        )

        switch mode {
        case .host:
            processGuess(wordDrop, from: localPlayerID)
            return true
        case .guest:
            guard let clientPeer else { return false }
            send(
                .wordDrop(
                    roomID: roomID,
                    playerID: localPlayerID,
                    wordDrop: wordDrop
                ),
                through: clientPeer
            )
            return true
        case .idle:
            return false
        }
    }

    func stop() {
        stopTransport()
        mode = .idle
        connectionMode = nil
        localPlayerName = ""
        roomID = nil
        roomName = ""
        players = []
        playerIDs = []
        nearbyRooms = []
        gameSettings = Self.defaultGameSettings
        resetGameplayState()
        state = .idle
    }

    static func normalizedPlayerName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(24))
    }

    static func normalizedViewerWord(_ word: String) -> String {
        let singleLine = word
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(singleLine.prefix(32))
    }

    private static func networkParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        return parameters
    }

    private func startWiFiHosting(
        roomID: UUID,
        roomName: String
    ) -> Bool {
        do {
            let listener = try NWListener(using: Self.networkParameters())
            let txtRecord = NWTXTRecord([
                "roomID": roomID.uuidString,
                "roomName": roomName
            ])

            listener.service = NWListener.Service(
                name: roomID.uuidString,
                type: Self.bonjourServiceType,
                txtRecord: txtRecord
            )
            listener.newConnectionLimit = 15

            let currentGeneration = generation
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }

                Task { @MainActor in
                    self.accept(
                        connection,
                        generation: currentGeneration
                    )
                }
            }
            listener.stateUpdateHandler = { [weak self] newState in
                guard let self else { return }

                Task { @MainActor in
                    self.handleListenerState(
                        newState,
                        generation: currentGeneration
                    )
                }
            }

            self.listener = listener
            listener.start(queue: networkQueue)
            return true
        } catch {
            state = .failed("Could not create the room: \(error.localizedDescription)")
            return false
        }
    }

    private func startWiFiSearch() {
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(
                type: Self.bonjourServiceType,
                domain: nil
            ),
            using: Self.networkParameters()
        )
        let currentGeneration = generation

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }

            Task { @MainActor in
                self.updateNearbyWiFiRooms(
                    from: results,
                    generation: currentGeneration
                )
            }
        }
        browser.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }

            Task { @MainActor in
                self.handleBrowserState(
                    newState,
                    generation: currentGeneration
                )
            }
        }

        self.browser = browser
        browser.start(queue: networkQueue)
    }

    private func stopTransport() {
        generation += 1
        roundTimerTask?.cancel()
        roundTimerTask = nil
        activeWordDrops.removeAll()

        listener?.newConnectionHandler = nil
        listener?.stateUpdateHandler = nil
        listener?.cancel()
        listener = nil

        browser?.browseResultsChangedHandler = nil
        browser?.stateUpdateHandler = nil
        browser?.cancel()
        browser = nil

        clientConnection?.stateUpdateHandler = nil
        clientConnection?.cancel()
        clientConnection = nil

        for connection in hostConnections.values {
            connection.stateUpdateHandler = nil
            connection.cancel()
        }

        bluetoothTransport.stop()
        hostConnections.removeAll()
        hostPeers.removeAll()
        clientPeer = nil
        playerNamesByPeer.removeAll()
        playerIDsByPeer.removeAll()
        receiveBuffers.removeAll()
        scannedRoomID = nil
        nearbyRooms = []
    }

    private func handleListenerState(
        _ newState: NWListener.State,
        generation: Int
    ) {
        guard generation == self.generation,
              mode == .host,
              connectionMode == .wifi else {
            return
        }

        switch newState {
        case .ready:
            state = .hosting
        case .failed(let error):
            state = .failed("Room advertising failed: \(error.localizedDescription)")
        case .waiting(let error):
            state = .failed("Waiting for the local network: \(error.localizedDescription)")
        case .setup, .cancelled:
            break
        @unknown default:
            break
        }
    }

    private func handleBrowserState(
        _ newState: NWBrowser.State,
        generation: Int
    ) {
        guard generation == self.generation,
              mode == .guest,
              connectionMode == .wifi else {
            return
        }

        switch newState {
        case .ready:
            if scannedRoomID == nil, clientConnection == nil {
                state = .searching
            }
        case .failed(let error):
            state = .failed("Room search failed: \(error.localizedDescription)")
        case .waiting(let error):
            state = .failed("Waiting for the local network: \(error.localizedDescription)")
        case .setup, .cancelled:
            break
        @unknown default:
            break
        }
    }

    private func updateNearbyWiFiRooms(
        from results: Set<NWBrowser.Result>,
        generation: Int
    ) {
        guard generation == self.generation,
              mode == .guest,
              connectionMode == .wifi else {
            return
        }

        var roomsByID: [UUID: NearbyRoom] = [:]

        for result in results {
            guard case .bonjour(let txtRecord) = result.metadata,
                  let roomIDString = txtRecord.dictionary["roomID"],
                  let roomID = UUID(uuidString: roomIDString),
                  let roomName = txtRecord.dictionary["roomName"] else {
                continue
            }

            roomsByID[roomID] = NearbyRoom(
                roomID: roomID,
                roomName: roomName,
                endpoint: .wifi(result.endpoint)
            )
        }

        nearbyRooms = roomsByID.values.sorted {
            $0.roomName.localizedCaseInsensitiveCompare($1.roomName)
                == .orderedAscending
        }
        joinScannedRoomIfAvailable()
    }

    private func accept(
        _ connection: NWConnection,
        generation: Int
    ) {
        guard generation == self.generation,
              mode == .host,
              connectionMode == .wifi else {
            connection.cancel()
            return
        }

        let identifier = ObjectIdentifier(connection)
        let peer = TransportPeer.wifi(identifier)
        hostConnections[identifier] = connection
        hostPeers.insert(peer)
        receiveBuffers[peer] = Data()
        configure(
            connection,
            isHostConnection: true,
            generation: generation
        )
        connection.start(queue: networkQueue)
    }

    private func configure(
        _ connection: NWConnection,
        isHostConnection: Bool,
        generation: Int
    ) {
        connection.stateUpdateHandler = { [weak self, weak connection] newState in
            guard let self, let connection else { return }

            Task { @MainActor in
                self.handleConnectionState(
                    newState,
                    connection: connection,
                    isHostConnection: isHostConnection,
                    generation: generation
                )
            }
        }
    }

    private func handleConnectionState(
        _ newState: NWConnection.State,
        connection: NWConnection,
        isHostConnection: Bool,
        generation: Int
    ) {
        guard generation == self.generation else { return }

        switch newState {
        case .ready:
            let peer = TransportPeer.wifi(ObjectIdentifier(connection))
            receiveBuffers[peer] = Data()
            receive(
                on: connection,
                isHostConnection: isHostConnection,
                generation: generation
            )

            if !isHostConnection {
                clientPeer = peer
                sendJoin(through: peer)
            }
        case .failed(let error):
            networkConnectionEnded(
                connection,
                isHostConnection: isHostConnection,
                message: error.localizedDescription
            )
        case .cancelled:
            networkConnectionEnded(
                connection,
                isHostConnection: isHostConnection,
                message: "The connection was closed."
            )
        case .setup, .preparing, .waiting:
            break
        @unknown default:
            break
        }
    }

    private func receive(
        on connection: NWConnection,
        isHostConnection: Bool,
        generation: Int
    ) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65_536
        ) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }

            Task { @MainActor in
                guard generation == self.generation else { return }

                let peer = TransportPeer.wifi(ObjectIdentifier(connection))
                if let data, !data.isEmpty {
                    self.consume(data, from: peer)
                }

                if let error {
                    self.networkConnectionEnded(
                        connection,
                        isHostConnection: isHostConnection,
                        message: error.localizedDescription
                    )
                } else if isComplete {
                    self.networkConnectionEnded(
                        connection,
                        isHostConnection: isHostConnection,
                        message: "The connection was closed."
                    )
                } else {
                    self.receive(
                        on: connection,
                        isHostConnection: isHostConnection,
                        generation: generation
                    )
                }
            }
        }
    }

    private func networkConnectionEnded(
        _ connection: NWConnection,
        isHostConnection: Bool,
        message: String
    ) {
        let identifier = ObjectIdentifier(connection)
        hostConnections[identifier] = nil
        if clientConnection === connection {
            clientConnection = nil
        }
        peerEnded(
            .wifi(identifier),
            isHostConnection: isHostConnection,
            message: message
        )
    }

    private func handleBluetoothEvent(_ event: BluetoothRoomEvent) {
        switch event {
        case .hostReady:
            guard mode == .host,
                  connectionMode == .bluetooth else {
                return
            }
            state = .hosting
        case .roomsChanged(let rooms):
            guard mode == .guest,
                  connectionMode == .bluetooth,
                  clientPeer == nil else {
                return
            }

            nearbyRooms = rooms.map {
                NearbyRoom(
                    roomID: $0.roomID,
                    roomName: $0.roomName,
                    endpoint: .bluetooth($0.peripheralID)
                )
            }
            joinScannedRoomIfAvailable()
        case .peerConnected(let peerID):
            guard mode == .host,
                  connectionMode == .bluetooth else {
                return
            }

            let peer = TransportPeer.bluetooth(peerID)
            hostPeers.insert(peer)
            receiveBuffers[peer] = Data()
        case .guestReady(let peerID):
            guard mode == .guest,
                  connectionMode == .bluetooth else {
                return
            }

            let peer = TransportPeer.bluetooth(peerID)
            clientPeer = peer
            receiveBuffers[peer] = Data()
            sendJoin(through: peer)
        case .data(let peerID, let data):
            let peer = TransportPeer.bluetooth(peerID)
            if mode == .host {
                guard hostPeers.contains(peer) else { return }
            } else {
                guard mode == .guest,
                      clientPeer == peer else {
                    return
                }
            }
            consume(data, from: peer)
        case .peerDisconnected(let peerID, let message):
            peerEnded(
                .bluetooth(peerID),
                isHostConnection: mode == .host,
                message: message
            )
        case .failed(let message):
            guard mode != .idle,
                  connectionMode == .bluetooth else {
                return
            }
            state = .failed(message)
        }
    }

    private func joinScannedRoomIfAvailable() {
        guard let scannedRoomID,
              let scannedRoom = nearbyRooms.first(
                where: { $0.roomID == scannedRoomID }
              ) else {
            return
        }

        join(scannedRoom)
    }

    private func sendJoin(through peer: TransportPeer) {
        guard let roomID else { return }

        send(
            .join(
                roomID: roomID,
                playerID: localPlayerID,
                playerName: localPlayerName
            ),
            through: peer
        )
    }

    private func consume(_ data: Data, from peer: TransportPeer) {
        var buffer = receiveBuffers[peer, default: Data()]
        buffer.append(data)

        while buffer.count >= MemoryLayout<UInt32>.size {
            let packetStart = buffer.startIndex
            let payloadStart = buffer.index(
                packetStart,
                offsetBy: MemoryLayout<UInt32>.size
            )
            let payloadLength = buffer[packetStart..<payloadStart].reduce(UInt32(0)) {
                ($0 << 8) | UInt32($1)
            }

            guard payloadLength <= Self.maximumMessageSize else {
                reject(peer)
                receiveBuffers[peer] = nil
                return
            }

            let totalLength = MemoryLayout<UInt32>.size + Int(payloadLength)
            guard buffer.count >= totalLength else { break }

            let packetEnd = buffer.index(packetStart, offsetBy: totalLength)
            let payload = buffer.subdata(in: payloadStart..<packetEnd)
            buffer = Data(buffer[packetEnd...])

            if let message = try? JSONDecoder().decode(
                RoomWireMessage.self,
                from: payload
            ) {
                handle(message, from: peer)
            }
        }

        receiveBuffers[peer] = buffer
    }

    private func handle(
        _ message: RoomWireMessage,
        from peer: TransportPeer
    ) {
        switch (mode, message.kind) {
        case (.host, .join):
            guard hostPeers.contains(peer),
                  message.roomID == roomID,
                  let playerID = message.playerID,
                  playerID != localPlayerID,
                  !playerIDsByPeer.values.contains(playerID),
                  let playerName = message.playerName else {
                reject(peer)
                return
            }

            let normalizedName = Self.normalizedPlayerName(playerName)
            guard !normalizedName.isEmpty else {
                reject(peer)
                return
            }

            playerNamesByPeer[peer] = normalizedName
            playerIDsByPeer[peer] = playerID
            refreshRoster()
            sendGameSnapshot(to: peer, playerID: playerID)

        case (.guest, .roster):
            guard message.roomID == roomID,
                  let roomName = message.roomName,
                  let players = message.players,
                  let playerIDs = message.playerIDs,
                  players.count == playerIDs.count else {
                return
            }

            self.roomName = roomName
            self.players = players
            self.playerIDs = playerIDs
            guessedPlayerIDs.formIntersection(playerIDs)
            state = .connected

        case (.guest, .settings):
            guard message.roomID == roomID,
                  let settings = message.settings,
                  Self.availableTimeLimits.contains(settings.timeLimit),
                  settings.numberOfRounds >= 1 else {
                return
            }
            gameSettings = settings

        case (.guest, .startGame):
            guard message.roomID == roomID,
                  let currentDrawerID = message.currentDrawerID,
                  let roundNumber = message.roundNumber,
                  (1...gameSettings.numberOfRounds).contains(roundNumber) else {
                return
            }

            currentRound = roundNumber
            isGameStarted = true
            prepareForChoosing(drawerID: currentDrawerID)

        case (.guest, .wordChoices):
            guard message.roomID == roomID,
                  gamePhase == .choosingWord,
                  message.currentDrawerID == localPlayerID,
                  currentDrawerID == localPlayerID,
                  let choices = message.wordChoices,
                  choices.count == 3 else {
                return
            }
            wordChoices = choices

        case (.host, .selectWord):
            guard message.roomID == roomID,
                  gamePhase == .choosingWord,
                  let currentDrawerID,
                  let playerID = message.playerID,
                  playerID == currentDrawerID,
                  playerIDsByPeer[peer] == currentDrawerID,
                  let selectedWord = message.selectedWord,
                  pendingWordChoices.contains(selectedWord) else {
                return
            }
            beginDrawingRound(with: selectedWord)

        case (.guest, .roundStarted):
            guard message.roomID == roomID,
                  let currentDrawerID = message.currentDrawerID,
                  let remainingSeconds = message.remainingSeconds,
                  remainingSeconds > 0 else {
                return
            }

            self.currentDrawerID = currentDrawerID
            gamePhase = .drawing
            wordChoices = []
            if currentDrawerID != localPlayerID {
                wordToDraw = nil
            }
            guessedPlayerIDs = []
            activeWordDrops.removeAll()
            sketchTools.reset()
            startRoundCountdown(
                seconds: remainingSeconds,
                hostControlsRound: false
            )

        case (.host, .drawing):
            guard message.roomID == roomID,
                  gamePhase == .drawing,
                  let currentDrawerID,
                  message.playerID == currentDrawerID,
                  playerIDsByPeer[peer] == currentDrawerID,
                  let drawingCommand = message.drawingCommand else {
                return
            }

            sketchTools.applyRemote(drawingCommand)
            broadcast(message, excluding: peer)

        case (.guest, .drawing):
            guard message.roomID == roomID,
                  gamePhase == .drawing,
                  let currentDrawerID,
                  message.playerID == currentDrawerID,
                  let drawingCommand = message.drawingCommand else {
                return
            }
            sketchTools.applyRemote(drawingCommand)

        case (.host, .wordDrop):
            guard message.roomID == roomID,
                  gamePhase == .drawing,
                  let senderID = message.playerID,
                  playerIDsByPeer[peer] == senderID,
                  let incomingWordDrop = message.wordDrop,
                  let approvedWordDrop = validatedWordDrop(incomingWordDrop),
                  !activeWordDrops.contains(where: { $0.id == approvedWordDrop.id }) else {
                return
            }
            processGuess(approvedWordDrop, from: senderID)

        case (.guest, .wordDrop):
            guard message.roomID == roomID,
                  gamePhase == .drawing,
                  let incomingWordDrop = message.wordDrop,
                  let approvedWordDrop = validatedWordDrop(incomingWordDrop) else {
                return
            }
            presentWordDrop(approvedWordDrop)

        case (.host, .skipTurn):
            guard message.roomID == roomID,
                  gamePhase == .drawing,
                  let currentDrawerID,
                  message.playerID == currentDrawerID,
                  playerIDsByPeer[peer] == currentDrawerID else {
                return
            }
            finishRound()

        case (.guest, .drawingTurn):
            guard message.roomID == roomID,
                  isGameStarted,
                  let currentDrawerID = message.currentDrawerID,
                  let roundNumber = message.roundNumber,
                  (1...gameSettings.numberOfRounds).contains(roundNumber),
                  playerIDs.contains(currentDrawerID) else {
                return
            }
            currentRound = roundNumber
            prepareForChoosing(drawerID: currentDrawerID)

        case (.guest, .guessStatus):
            guard message.roomID == roomID,
                  gamePhase == .drawing,
                  let guessedPlayerIDs = message.guessedPlayerIDs else {
                return
            }
            self.guessedPlayerIDs = Set(
                guessedPlayerIDs.filter { playerIDs.contains($0) }
            )

        case (.guest, .gameEnded):
            guard message.roomID == roomID else { return }
            resetGameplayState()

        default:
            break
        }
    }

    private func validatedWordDrop(_ wordDrop: WordDrop) -> WordDrop? {
        let normalizedWord = Self.normalizedViewerWord(wordDrop.text)
        guard !normalizedWord.isEmpty,
              wordDrop.horizontalPosition.isFinite else {
            return nil
        }

        return WordDrop(
            id: wordDrop.id,
            text: normalizedWord,
            horizontalPosition: min(max(wordDrop.horizontalPosition, 0.08), 0.92)
        )
    }

    private func presentWordDrop(_ wordDrop: WordDrop) {
        guard !activeWordDrops.contains(where: { $0.id == wordDrop.id }) else {
            return
        }

        activeWordDrops.append(wordDrop)
        Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(4.25))
            } catch {
                return
            }
            self?.activeWordDrops.removeAll { $0.id == wordDrop.id }
        }
    }

    private func processGuess(_ wordDrop: WordDrop, from playerID: UUID) {
        guard mode == .host,
              gamePhase == .drawing,
              playerID != currentDrawerID,
              playerIDs.contains(playerID),
              !guessedPlayerIDs.contains(playerID),
              let roomID,
              let currentSecretWord else {
            return
        }

        if Self.guessKey(wordDrop.text) == Self.guessKey(currentSecretWord) {
            guessedPlayerIDs.insert(playerID)
            broadcastGuessStatus()
            if allViewersHaveGuessed {
                scheduleRoundFinishAfterCorrectGuess()
            }
        } else {
            presentWordDrop(wordDrop)
            broadcast(
                .wordDrop(
                    roomID: roomID,
                    playerID: playerID,
                    wordDrop: wordDrop
                )
            )
        }
    }

    private static func guessKey(_ word: String) -> String {
        let folded = word.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return folded.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }

    private var allViewersHaveGuessed: Bool {
        guard let currentDrawerID else { return false }
        let viewerIDs = Set(playerIDs.filter { $0 != currentDrawerID })
        return !viewerIDs.isEmpty && viewerIDs.isSubset(of: guessedPlayerIDs)
    }

    private func resetGameplayState() {
        roundTimerTask?.cancel()
        roundTimerTask = nil
        isGameStarted = false
        gamePhase = .lobby
        currentDrawerID = nil
        pendingWordChoices = []
        wordChoices = []
        currentSecretWord = nil
        wordToDraw = nil
        remainingSeconds = 0
        currentRound = 0
        gamePlayerIDs = []
        guessedPlayerIDs = []
        activeWordDrops.removeAll()
        sketchTools.reset()
    }

    private func prepareForChoosing(drawerID: UUID) {
        roundTimerTask?.cancel()
        roundTimerTask = nil
        currentDrawerID = drawerID
        gamePhase = .choosingWord
        pendingWordChoices = []
        wordChoices = []
        currentSecretWord = nil
        wordToDraw = nil
        remainingSeconds = 0
        guessedPlayerIDs = []
        activeWordDrops.removeAll()
        sketchTools.reset()
    }

    private func beginTurn(
        drawerID: UUID,
        choices: [String],
        isInitialTurn: Bool
    ) {
        guard mode == .host,
              isGameStarted,
              choices.count == 3,
              let roomID else {
            return
        }

        prepareForChoosing(drawerID: drawerID)
        pendingWordChoices = choices
        if drawerID == localPlayerID {
            wordChoices = choices
        }

        if isInitialTurn {
            broadcast(
                .startGame(
                    roomID: roomID,
                    currentDrawerID: drawerID,
                    roundNumber: currentRound
                )
            )
        } else {
            broadcast(
                .drawingTurn(
                    roomID: roomID,
                    currentDrawerID: drawerID,
                    roundNumber: currentRound
                )
            )
        }

        if drawerID != localPlayerID,
           let drawerPeer = peer(for: drawerID) {
            send(
                .wordChoices(
                    roomID: roomID,
                    currentDrawerID: drawerID,
                    choices: choices
                ),
                through: drawerPeer
            )
        }
    }

    private func beginDrawingRound(with word: String) {
        guard mode == .host,
              gamePhase == .choosingWord,
              pendingWordChoices.contains(word),
              let roomID,
              let currentDrawerID else {
            return
        }

        currentSecretWord = word
        wordToDraw = currentDrawerID == localPlayerID ? word : nil
        pendingWordChoices = []
        wordChoices = []
        guessedPlayerIDs = []
        activeWordDrops.removeAll()
        sketchTools.reset()
        gamePhase = .drawing

        broadcast(
            .roundStarted(
                roomID: roomID,
                currentDrawerID: currentDrawerID,
                remainingSeconds: gameSettings.timeLimit
            )
        )
        startRoundCountdown(
            seconds: gameSettings.timeLimit,
            hostControlsRound: true
        )
    }

    private func startRoundCountdown(
        seconds: Int,
        hostControlsRound: Bool
    ) {
        roundTimerTask?.cancel()
        remainingSeconds = max(seconds, 0)

        roundTimerTask = Task { [weak self] in
            while let self, self.remainingSeconds > 0 {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self.remainingSeconds -= 1
            }

            guard hostControlsRound,
                  let self,
                  self.mode == .host,
                  self.gamePhase == .drawing else {
                return
            }
            self.finishRound()
        }
    }

    private func scheduleRoundFinishAfterCorrectGuess() {
        roundTimerTask?.cancel()
        roundTimerTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }

            guard let self,
                  self.mode == .host,
                  self.gamePhase == .drawing,
                  self.allViewersHaveGuessed else {
                return
            }
            self.finishRound()
        }
    }

    private func finishRound() {
        guard mode == .host,
              isGameStarted else {
            return
        }

        roundTimerTask?.cancel()
        roundTimerTask = nil
        advanceDrawingTurn()
    }

    private func advanceDrawingTurn(
        previousOrder: [UUID]? = nil
    ) {
        guard isGameStarted else { return }

        let turnOrder = previousOrder ?? gamePlayerIDs
        let activePlayerIDs = turnOrder.filter { playerIDs.contains($0) }
        gamePlayerIDs = activePlayerIDs

        guard !activePlayerIDs.isEmpty,
              let currentDrawerID,
              let currentIndex = turnOrder.firstIndex(of: currentDrawerID) else {
            endGame()
            return
        }

        var nextDrawerID: UUID?
        var wrappedToNextRound = false

        for offset in 1...turnOrder.count {
            let candidateIndex = (currentIndex + offset) % turnOrder.count
            let candidate = turnOrder[candidateIndex]
            if activePlayerIDs.contains(candidate) {
                nextDrawerID = candidate
                wrappedToNextRound = candidateIndex <= currentIndex
                break
            }
        }

        guard let nextDrawerID else {
            endGame()
            return
        }

        if wrappedToNextRound {
            guard currentRound < gameSettings.numberOfRounds else {
                endGame()
                return
            }
            currentRound += 1
        }

        do {
            let choices = try WordLibrary.choices(for: gameSettings.topic)
            beginTurn(
                drawerID: nextDrawerID,
                choices: choices,
                isInitialTurn: false
            )
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func endGame() {
        guard mode == .host,
              let roomID else {
            return
        }

        broadcast(.gameEnded(roomID: roomID))
        resetGameplayState()
    }

    private func sendGameSnapshot(
        to peer: TransportPeer,
        playerID: UUID
    ) {
        guard mode == .host,
              let roomID else {
            return
        }

        send(
            .settings(roomID: roomID, settings: gameSettings),
            through: peer
        )

        guard isGameStarted,
              let currentDrawerID else {
            return
        }

        send(
            .startGame(
                roomID: roomID,
                currentDrawerID: currentDrawerID,
                roundNumber: currentRound
            ),
            through: peer
        )

        switch gamePhase {
        case .lobby:
            break
        case .choosingWord:
            if playerID == currentDrawerID {
                send(
                    .wordChoices(
                        roomID: roomID,
                        currentDrawerID: currentDrawerID,
                        choices: pendingWordChoices
                    ),
                    through: peer
                )
            }
        case .drawing:
            send(
                .roundStarted(
                    roomID: roomID,
                    currentDrawerID: currentDrawerID,
                    remainingSeconds: max(remainingSeconds, 1)
                ),
                through: peer
            )
            send(
                .drawing(
                    roomID: roomID,
                    playerID: currentDrawerID,
                    command: sketchTools.snapshotCommand
                ),
                through: peer
            )
            send(
                .guessStatus(
                    roomID: roomID,
                    guessedPlayerIDs: orderedGuessedPlayerIDs
                ),
                through: peer
            )
        }
    }

    private func refreshRoster() {
        guard mode == .host,
              let roomID else {
            return
        }

        let previousDrawerID = currentDrawerID
        let previousGamePlayerIDs = gamePlayerIDs
        let guests: [(name: String, playerID: UUID)] = playerNamesByPeer
            .compactMap { peer, name in
                guard let playerID = playerIDsByPeer[peer] else {
                    return nil
                }
                return (name: name, playerID: playerID)
            }
            .sorted { first, second in
                let comparison = first.name.localizedCaseInsensitiveCompare(second.name)
                if comparison == .orderedSame {
                    return first.playerID.uuidString < second.playerID.uuidString
                }
                return comparison == .orderedAscending
            }

        players = [localPlayerName] + guests.map { $0.name }
        playerIDs = [localPlayerID] + guests.map { $0.playerID }
        gamePlayerIDs.removeAll { !playerIDs.contains($0) }
        guessedPlayerIDs.formIntersection(playerIDs)

        broadcast(
            .roster(
                roomID: roomID,
                roomName: roomName,
                players: players,
                playerIDs: playerIDs
            )
        )
        broadcastSettings()

        guard isGameStarted else { return }

        if let previousDrawerID,
           !playerIDs.contains(previousDrawerID) {
            advanceDrawingTurn(previousOrder: previousGamePlayerIDs)
        } else if gamePhase == .drawing {
            broadcastGuessStatus()
            if allViewersHaveGuessed {
                scheduleRoundFinishAfterCorrectGuess()
            }
        }
    }

    private var orderedGuessedPlayerIDs: [UUID] {
        playerIDs.filter { guessedPlayerIDs.contains($0) }
    }

    private func broadcastSettings() {
        guard mode == .host,
              let roomID else {
            return
        }
        broadcast(.settings(roomID: roomID, settings: gameSettings))
    }

    private func broadcastGuessStatus() {
        guard mode == .host,
              let roomID else {
            return
        }
        broadcast(
            .guessStatus(
                roomID: roomID,
                guessedPlayerIDs: orderedGuessedPlayerIDs
            )
        )
    }

    private func peer(for playerID: UUID) -> TransportPeer? {
        playerIDsByPeer.first { $0.value == playerID }?.key
    }

    private func sendLocalDrawing(_ command: SketchCommand) {
        guard canDraw,
              let roomID else {
            return
        }

        let message = RoomWireMessage.drawing(
            roomID: roomID,
            playerID: localPlayerID,
            command: command
        )

        switch mode {
        case .host:
            broadcast(message)
        case .guest:
            guard let clientPeer else { return }
            send(message, through: clientPeer)
        case .idle:
            break
        }
    }

    private func broadcast(
        _ message: RoomWireMessage,
        excluding excludedPeer: TransportPeer? = nil
    ) {
        for peer in hostPeers where peer != excludedPeer {
            send(message, through: peer)
        }
    }

    private func send(
        _ message: RoomWireMessage,
        through peer: TransportPeer
    ) {
        guard let payload = try? JSONEncoder().encode(message),
              payload.count <= Int(Self.maximumMessageSize) else {
            return
        }

        var length = UInt32(payload.count).bigEndian
        var packet = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        packet.append(payload)

        switch peer {
        case .wifi(let identifier):
            let connection: NWConnection?
            if let hostConnection = hostConnections[identifier] {
                connection = hostConnection
            } else if let clientConnection,
                      ObjectIdentifier(clientConnection) == identifier {
                connection = clientConnection
            } else {
                connection = nil
            }

            guard let connection else { return }
            connection.send(
                content: packet,
                completion: .contentProcessed { _ in }
            )
        case .bluetooth(let peerID):
            bluetoothTransport.send(packet, to: peerID)
        }
    }

    private func reject(_ peer: TransportPeer) {
        switch peer {
        case .wifi(let identifier):
            hostConnections[identifier]?.cancel()
        case .bluetooth(let peerID):
            bluetoothTransport.disconnect(peerID: peerID)
        }

        peerEnded(
            peer,
            isHostConnection: mode == .host,
            message: "The connection request was invalid."
        )
    }

    private func peerEnded(
        _ peer: TransportPeer,
        isHostConnection: Bool,
        message: String
    ) {
        receiveBuffers[peer] = nil

        if isHostConnection {
            let wasKnown = hostPeers.contains(peer)
                || playerNamesByPeer[peer] != nil
            hostPeers.remove(peer)
            playerNamesByPeer[peer] = nil
            playerIDsByPeer[peer] = nil
            if wasKnown, mode == .host {
                refreshRoster()
            }
        } else if mode == .guest,
                  clientPeer == nil || clientPeer == peer {
            let shouldReportLoss = state == .connected
                || state == .connecting
                || isGameStarted
            clientPeer = nil
            resetGameplayState()
            if shouldReportLoss {
                state = .failed("Connection lost: \(message)")
            }
        }
    }

}
