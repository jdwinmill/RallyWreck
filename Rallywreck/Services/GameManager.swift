import Foundation
import MultipeerConnectivity

/// Host-side game logic: join handling, turn selection, timer, elimination, game over
@Observable
final class GameManager {
    private let multipeerService: MultipeerService
    private let gameState: GameState

    private var turnTimer: Task<Void, Never>?
    private var currentTurnDuration: TimeInterval = 3.0
    private let timerShrinkFactor: Double = 0.92
    private let minimumDuration: TimeInterval = 0.5

    // Bot mode for solo testing
    private(set) var botPlayers: [Player] = []
    var botEnabled: Bool { !botPlayers.isEmpty }
    private var botTimer: Task<Void, Never>?

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
        let botNumber = botPlayers.count + 1
        let bot = Player(displayName: "Bot \(botNumber)")
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
        currentTurnDuration = 3.0
        gameState.eliminationStandings = []

        for i in gameState.players.indices {
            gameState.players[i].isEliminated = false
        }

        // Countdown: 3, 2, 1, GO
        Task {
            for i in (1...3).reversed() {
                gameState.phase = .countdown(remaining: i)
                multipeerService.sendToAll(.gameCountdown(remaining: i))
                try? await Task.sleep(for: .seconds(1))
            }
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
        currentTurnDuration = max(minimumDuration, currentTurnDuration * timerShrinkFactor)

        startNextTurn()
    }

    func returnToLobby() {
        turnTimer?.cancel()
        botTimer?.cancel()
        botPlayers.removeAll()
        gameState.reset()
        multipeerService.sendToAll(.returnToLobby(roster: gameState.players))
    }

    // MARK: - Private

    private func startNextTurn() {
        let active = gameState.activePlayers

        // Check win condition
        let onlyBotsLeft = !active.isEmpty && active.allSatisfy { p in botPlayers.contains { $0.id == p.id } }
        if active.count <= 1 || onlyBotsLeft {
            // If only bots remain, the last eliminated human is the implicit "loser" —
            // pick the first remaining active player as the nominal winner.
            let winner = active.first ?? gameState.players.first!
            gameState.phase = .gameOver(winnerName: winner.displayName)
            multipeerService.sendToAll(.gameOver(
                winnerID: winner.id,
                winnerName: winner.displayName,
                standings: gameState.eliminationStandings + active
            ))
            return
        }

        // Pick random active player (avoid same player twice in a row if possible)
        var candidates = active
        if candidates.count > 1, let current = gameState.activePlayerID {
            candidates.removeAll { $0.id == current }
        }
        let chosen = candidates.randomElement()!

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
        botTimer = Task { [weak self] in
            // Bot reacts between 30-80% of the available time
            let reactionTime = duration * Double.random(in: 0.3...0.8)
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
        gameState.phase = .elimination(eliminatedPlayerName: name)

        multipeerService.sendToAll(.playerEliminated(playerID: id, playerName: name))

        // Brief pause to show elimination, then next turn
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard case .elimination = gameState.phase else { return }
            gameState.phase = .playing
            startNextTurn()
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
        guard let playerID = multipeerService.peerToPlayerID[peer] else { return }
        gameState.players.removeAll { $0.id == playerID }

        if case .lobby = gameState.phase {
            multipeerService.sendToAll(.lobbyUpdate(roster: gameState.players))
        } else {
            // If mid-game and it was the active player, treat as elimination
            if gameState.activePlayerID == playerID {
                eliminatePlayer(id: playerID)
            } else if let index = gameState.players.firstIndex(where: { $0.id == playerID }) {
                gameState.players[index].isEliminated = true
            }
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
