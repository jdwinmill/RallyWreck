import Foundation
import MultipeerConnectivity

/// Host-side game logic: join handling, turn selection, timer, elimination, game over
@MainActor
@Observable
final class GameManager {
    private let multipeerService: MultipeerService
    private let gameState: GameState

    private var countdownTask: Task<Void, Never>?
    private var turnTimer: Task<Void, Never>?
    private var eliminationTimer: Task<Void, Never>?
    private var currentTurnDuration: TimeInterval = 3.0

    // Bot mode for solo testing
    private(set) var botPlayers: [Player] = []
    var botEnabled: Bool { !botPlayers.isEmpty }
    private var botTimer: Task<Void, Never>?
    private var nextBotNumber: Int = 1

    init(multipeerService: MultipeerService, gameState: GameState) {
        self.multipeerService = multipeerService
        self.gameState = gameState
    }

    func setupAsHost(localPlayer: Player) {
        gameState.isHost = true
        gameState.localPlayer = localPlayer
        gameState.players = [localPlayer]
        gameState.phase = .lobby

        multipeerService.onPeerConnected = { _ in
            // Peer connected; wait for joinRequest message
        }

        multipeerService.onPeerDisconnected = { [weak self] peer in
            self?.handlePeerDisconnected(peer)
        }

        multipeerService.onMessageReceived = { [weak self] message, peer in
            self?.handleMessageFromClient(message, from: peer)
        }
    }

    func addBot() {
        guard gameState.players.count < 5 else { return }
        let bot = Player(displayName: "Bot \(nextBotNumber)")
        nextBotNumber += 1
        botPlayers.append(bot)
        gameState.players.append(bot)
        multipeerService.sendToAll(.lobbyUpdate(roster: gameState.players))
    }

    func removeBot() {
        guard let bot = botPlayers.last else { return }
        botPlayers.removeLast()
        gameState.players.removeAll { $0.id == bot.id }
        multipeerService.sendToAll(.lobbyUpdate(roster: gameState.players))
    }

    func startGame() {
        guard gameState.players.count >= 2 else { return }
        currentTurnDuration = gameState.difficulty.startingDuration
        gameState.eliminationStandings = []

        // Stop discovering new players during the game
        multipeerService.stopBrowsingForPeers()

        for i in gameState.players.indices {
            gameState.players[i].isEliminated = false
        }

        // Sync difficulty + Countdown: 3, 2, 1, GO
        multipeerService.sendToAll(.gameStart(difficulty: gameState.difficulty.rawValue))
        countdownTask = Task {
            for i in (1...3).reversed() {
                guard !Task.isCancelled else { return }
                gameState.phase = .countdown(remaining: i)
                multipeerService.sendToAll(.gameCountdown(remaining: i))
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            gameState.phase = .playing
            startNextTurn()
        }
    }

    func handleTap(playerID: String) {
        guard case .playing = gameState.phase,
              gameState.activePlayerID == playerID else { return }

        turnTimer?.cancel()
        turnTimer = nil

        // Shrink timer
        let diff = gameState.difficulty
        currentTurnDuration = max(diff.minimumDuration, currentTurnDuration * diff.shrinkFactor)

        startNextTurn()
    }

    func returnToLobby() {
        countdownTask?.cancel()
        turnTimer?.cancel()
        botTimer?.cancel()
        eliminationTimer?.cancel()
        let botIDs = Set(botPlayers.map(\.id))
        botPlayers.removeAll()
        gameState.players.removeAll { botIDs.contains($0.id) }
        gameState.reset()
        multipeerService.sendToAll(.returnToLobby(roster: gameState.players))
        // Resume discovering new players
        multipeerService.resumeBrowsingForPeers()
    }

    // MARK: - Private

    private func startNextTurn() {
        turnTimer?.cancel()
        turnTimer = nil

        let active = gameState.activePlayers

        // Check win condition
        let onlyBotsLeft = !active.isEmpty && active.allSatisfy { p in botPlayers.contains { $0.id == p.id } }
        if active.count <= 1 || onlyBotsLeft {
            let winner = active.first ?? gameState.players.first
            let winnerName = winner?.displayName ?? "Nobody"
            gameState.phase = .gameOver(winnerName: winnerName)
            if let winner {
                multipeerService.sendToAll(.gameOver(
                    winnerID: winner.id,
                    winnerName: winner.displayName,
                    standings: gameState.eliminationStandings + active
                ))
            }
            return
        }

        // Pick random active player (avoid same player twice in a row if possible)
        var candidates = active
        if candidates.count > 1, let current = gameState.activePlayerID {
            candidates.removeAll { $0.id == current }
        }
        guard let chosen = candidates.randomElement() else { return }

        gameState.activePlayerID = chosen.id
        gameState.turnDuration = currentTurnDuration
        gameState.turnStartDate = Date()

        multipeerService.sendToAll(.turnStart(
            activePlayerID: chosen.id,
            duration: currentTurnDuration
        ))

        // If the chosen player is a bot, auto-tap after a random delay
        if botPlayers.contains(where: { $0.id == chosen.id }) {
            scheduleBotTap(botID: chosen.id, duration: currentTurnDuration)
        }

        // Start countdown timer
        let duration = currentTurnDuration
        let eliminateID = chosen.id
        turnTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.eliminatePlayer(id: eliminateID)
        }
    }

    private func scheduleBotTap(botID: String, duration: TimeInterval) {
        botTimer?.cancel()
        let range = gameState.difficulty.botReactionRange
        botTimer = Task { [weak self] in
            let reactionTime = duration * Double.random(in: range)
            try? await Task.sleep(for: .seconds(reactionTime))
            guard !Task.isCancelled else { return }
            self?.handleTap(playerID: botID)
        }
    }

    private func eliminatePlayer(id: String) {
        guard let index = gameState.players.firstIndex(where: { $0.id == id }) else { return }
        gameState.players[index].isEliminated = true
        gameState.eliminationStandings.insert(gameState.players[index], at: 0)

        let name = gameState.players[index].displayName
        gameState.phase = .elimination(eliminatedPlayerID: id, eliminatedPlayerName: name)

        multipeerService.sendToAll(.playerEliminated(playerID: id, playerName: name))

        // Brief pause to show elimination, then next turn
        eliminationTimer?.cancel()
        eliminationTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            guard case .elimination = self?.gameState.phase else { return }
            self?.gameState.phase = .playing
            self?.startNextTurn()
        }
    }

    private func handlePeerDisconnectedDuringGame(playerID: String, playerName: String) {
        // Cancel active turn if the disconnected player was up
        if gameState.activePlayerID == playerID {
            turnTimer?.cancel()
            turnTimer = nil
        }

        // Mark eliminated
        if let index = gameState.players.firstIndex(where: { $0.id == playerID }) {
            gameState.players[index].isEliminated = true
            gameState.eliminationStandings.insert(gameState.players[index], at: 0)
        }

        // If already showing an overlay (elimination or playerLeft), wait for it to finish
        // by letting the existing eliminationTimer complete, then queue this one
        let isShowingOverlay: Bool
        switch gameState.phase {
        case .elimination, .playerLeft:
            isShowingOverlay = true
        default:
            isShowingOverlay = false
        }

        if isShowingOverlay {
            // Let the current overlay finish, then show playerLeft
            let existingTimer = eliminationTimer
            eliminationTimer = Task { [weak self] in
                // Wait for the existing timer to complete
                _ = await existingTimer?.value
                guard !Task.isCancelled else { return }
                self?.gameState.phase = .playerLeft(playerName: playerName)
                try? await Task.sleep(for: .seconds(2.0))
                guard !Task.isCancelled else { return }
                guard case .playerLeft = self?.gameState.phase else { return }
                self?.gameState.phase = .playing
                self?.startNextTurn()
            }
        } else {
            gameState.phase = .playerLeft(playerName: playerName)
            eliminationTimer?.cancel()
            eliminationTimer = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.0))
                guard !Task.isCancelled else { return }
                guard case .playerLeft = self?.gameState.phase else { return }
                self?.gameState.phase = .playing
                self?.startNextTurn()
            }
        }
    }

    private func handleMessageFromClient(_ message: GameMessage, from peer: MCPeerID) {
        switch message {
        case .joinRequest(let playerName, let playerID):
            handleJoinRequest(playerName: playerName, playerID: playerID, from: peer)

        case .tapAction(let playerID):
            handleTap(playerID: playerID)

        default:
            break
        }
    }

    private func handleJoinRequest(playerName: String, playerID: String, from peer: MCPeerID) {
        guard case .lobby = gameState.phase else {
            multipeerService.send(.joinRejected(reason: "Game already in progress"), to: [peer])
            return
        }

        guard gameState.players.count < 5 else {
            multipeerService.send(.joinRejected(reason: "Game is full"), to: [peer])
            return
        }

        // Duplicate detection: if a player with this ID already exists, update their peer mapping
        // instead of adding a duplicate entry (handles reconnection)
        if let existingIndex = gameState.players.firstIndex(where: { $0.id == playerID }) {
            // Player is reconnecting — update their peer mapping
            multipeerService.mapPeer(peer, toPlayerID: playerID)
            let player = gameState.players[existingIndex]
            multipeerService.send(.joinAccepted(yourPlayer: player, roster: gameState.players), to: [peer])
            multipeerService.sendToAll(.lobbyUpdate(roster: gameState.players))
            return
        }

        // Use the player ID they sent so client and host agree
        let player = Player(id: playerID, displayName: playerName)
        multipeerService.mapPeer(peer, toPlayerID: player.id)
        gameState.players.append(player)

        // Send acceptance to the new player
        multipeerService.send(.joinAccepted(yourPlayer: player, roster: gameState.players), to: [peer])

        // Broadcast updated roster to everyone
        multipeerService.sendToAll(.lobbyUpdate(roster: gameState.players))
    }

    private func handlePeerDisconnected(_ peer: MCPeerID) {
        // NOTE: This is called BEFORE mappings are removed from MultipeerService,
        // so peerToPlayerID[peer] is still valid here.
        guard let playerID = multipeerService.peerToPlayerID[peer] else { return }
        let playerName = gameState.players.first(where: { $0.id == playerID })?.displayName ?? "Player"

        if case .lobby = gameState.phase {
            gameState.players.removeAll { $0.id == playerID }
            multipeerService.sendToAll(.lobbyUpdate(roster: gameState.players))
        } else {
            handlePeerDisconnectedDuringGame(playerID: playerID, playerName: playerName)
        }
    }
}

// Extension to allow creating Player with a specific ID (for join handling)
extension Player {
    init(id: String, displayName: String, isHost: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.isHost = isHost
        self.isEliminated = false
    }
}
