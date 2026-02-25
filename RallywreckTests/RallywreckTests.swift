import Testing
import Foundation
@testable import Rallywreck

// MARK: - Player Tests

struct PlayerTests {
    @Test func playerCreation() {
        let player = Player(displayName: "Alice")
        #expect(!player.id.isEmpty)
        #expect(player.displayName == "Alice")
        #expect(player.isHost == false)
        #expect(player.isEliminated == false)
    }

    @Test func playerCreationAsHost() {
        let player = Player(displayName: "Host", isHost: true)
        #expect(player.isHost == true)
    }

    @Test func playerCreationWithExplicitID() {
        let player = Player(id: "custom-id", displayName: "Bob")
        #expect(player.id == "custom-id")
        #expect(player.displayName == "Bob")
    }

    @Test func playerUniqueIDs() {
        let p1 = Player(displayName: "A")
        let p2 = Player(displayName: "B")
        #expect(p1.id != p2.id)
    }

    @Test func playerCodable() throws {
        let player = Player(displayName: "Test", isHost: true)
        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(Player.self, from: data)
        #expect(decoded.id == player.id)
        #expect(decoded.displayName == player.displayName)
        #expect(decoded.isHost == player.isHost)
        #expect(decoded.isEliminated == player.isEliminated)
    }

    @Test func playerHashable() {
        let p1 = Player(id: "same-id", displayName: "A")
        let p2 = Player(id: "same-id", displayName: "A")
        let set: Set<Player> = [p1, p2]
        // Identical values should collapse in a set
        #expect(set.count == 1)
    }

    @Test func playerIdentifiable() {
        let p1 = Player(id: "id-1", displayName: "A")
        let p2 = Player(id: "id-2", displayName: "A")
        // Different IDs means different identity
        #expect(p1.id != p2.id)
    }
}

// MARK: - Difficulty Tests

struct DifficultyTests {
    @Test func allDifficulties() {
        let all = Difficulty.allCases
        #expect(all.count == 4)
        #expect(all == [.easy, .standard, .medium, .hard])
    }

    @Test func labels() {
        #expect(Difficulty.easy.label == "EASY")
        #expect(Difficulty.standard.label == "STANDARD")
        #expect(Difficulty.medium.label == "MEDIUM")
        #expect(Difficulty.hard.label == "HARD")
    }

    @Test func startingDurations() {
        #expect(Difficulty.easy.startingDuration == 5.0)
        #expect(Difficulty.standard.startingDuration == 3.0)
        #expect(Difficulty.medium.startingDuration == 3.0)
        #expect(Difficulty.hard.startingDuration == 3.0)
    }

    @Test func shrinkFactors() {
        #expect(Difficulty.easy.shrinkFactor == 0.97)
        #expect(Difficulty.standard.shrinkFactor == 0.92)
    }

    @Test func minimumDurations() {
        #expect(Difficulty.easy.minimumDuration == 1.5)
        #expect(Difficulty.standard.minimumDuration == 0.5)
    }

    @Test func buttonSizes() {
        #expect(Difficulty.easy.buttonSize() == 240)
        #expect(Difficulty.standard.buttonSize() == 200)
        // medium and hard return random sizes from varyingSizes
        let medSize = Difficulty.medium.buttonSize()
        #expect(Difficulty.varyingSizes.contains(medSize))
    }

    @Test func hidesInactiveButton() {
        #expect(Difficulty.easy.hidesInactiveButton == false)
        #expect(Difficulty.standard.hidesInactiveButton == false)
        #expect(Difficulty.medium.hidesInactiveButton == false)
        #expect(Difficulty.hard.hidesInactiveButton == true)
    }

    @Test func nextCycles() {
        #expect(Difficulty.easy.next() == .standard)
        #expect(Difficulty.standard.next() == .medium)
        #expect(Difficulty.medium.next() == .hard)
        #expect(Difficulty.hard.next() == .easy)
    }

    @Test func rawValueCodable() {
        #expect(Difficulty(rawValue: "easy") == .easy)
        #expect(Difficulty(rawValue: "standard") == .standard)
        #expect(Difficulty(rawValue: "invalid") == nil)
    }

    @Test func botReactionRanges() {
        let easyRange = Difficulty.easy.botReactionRange
        #expect(easyRange.lowerBound == 0.5)
        #expect(easyRange.upperBound == 0.95)

        let stdRange = Difficulty.standard.botReactionRange
        #expect(stdRange.lowerBound == 0.3)
        #expect(stdRange.upperBound == 0.8)
    }
}

// MARK: - GamePhase Tests

struct GamePhaseTests {
    @Test func phaseEquality() {
        #expect(GamePhase.lobby == GamePhase.lobby)
        #expect(GamePhase.playing == GamePhase.playing)
        #expect(GamePhase.countdown(remaining: 3) == GamePhase.countdown(remaining: 3))
        #expect(GamePhase.countdown(remaining: 3) != GamePhase.countdown(remaining: 2))
        #expect(GamePhase.elimination(eliminatedPlayerID: "id", eliminatedPlayerName: "A") == GamePhase.elimination(eliminatedPlayerID: "id", eliminatedPlayerName: "A"))
        #expect(GamePhase.elimination(eliminatedPlayerID: "id", eliminatedPlayerName: "A") != GamePhase.elimination(eliminatedPlayerID: "id", eliminatedPlayerName: "B"))
        #expect(GamePhase.gameOver(winnerName: "X") == GamePhase.gameOver(winnerName: "X"))
        #expect(GamePhase.playerLeft(playerName: "Y") == GamePhase.playerLeft(playerName: "Y"))
    }

    @Test func phaseCodable() throws {
        let phases: [GamePhase] = [
            .lobby,
            .countdown(remaining: 2),
            .playing,
            .elimination(eliminatedPlayerID: "id", eliminatedPlayerName: "Test"),
            .playerLeft(playerName: "Left"),
            .gameOver(winnerName: "Winner"),
        ]
        for phase in phases {
            let data = try JSONEncoder().encode(phase)
            let decoded = try JSONDecoder().decode(GamePhase.self, from: data)
            #expect(decoded == phase)
        }
    }
}

// MARK: - GameMessage Tests

struct GameMessageTests {
    @Test func joinRequestCodable() throws {
        let msg = GameMessage.joinRequest(playerName: "Alice", playerID: "id-123")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .joinRequest(let name, let id) = decoded {
            #expect(name == "Alice")
            #expect(id == "id-123")
        } else {
            Issue.record("Expected joinRequest")
        }
    }

    @Test func tapActionCodable() throws {
        let msg = GameMessage.tapAction(playerID: "player-1")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .tapAction(let id) = decoded {
            #expect(id == "player-1")
        } else {
            Issue.record("Expected tapAction")
        }
    }

    @Test func joinAcceptedCodable() throws {
        let player = Player(displayName: "Bob")
        let roster = [player, Player(displayName: "Alice")]
        let msg = GameMessage.joinAccepted(yourPlayer: player, roster: roster)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .joinAccepted(let p, let r) = decoded {
            #expect(p.id == player.id)
            #expect(r.count == 2)
        } else {
            Issue.record("Expected joinAccepted")
        }
    }

    @Test func joinRejectedCodable() throws {
        let msg = GameMessage.joinRejected(reason: "Game is full")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .joinRejected(let reason) = decoded {
            #expect(reason == "Game is full")
        } else {
            Issue.record("Expected joinRejected")
        }
    }

    @Test func lobbyUpdateCodable() throws {
        let roster = [Player(displayName: "A"), Player(displayName: "B")]
        let msg = GameMessage.lobbyUpdate(roster: roster)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .lobbyUpdate(let r) = decoded {
            #expect(r.count == 2)
        } else {
            Issue.record("Expected lobbyUpdate")
        }
    }

    @Test func gameStartCodable() throws {
        let msg = GameMessage.gameStart(difficulty: "hard")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .gameStart(let d) = decoded {
            #expect(d == "hard")
        } else {
            Issue.record("Expected gameStart")
        }
    }

    @Test func turnStartCodable() throws {
        let msg = GameMessage.turnStart(activePlayerID: "p1", duration: 2.5)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .turnStart(let id, let dur) = decoded {
            #expect(id == "p1")
            #expect(dur == 2.5)
        } else {
            Issue.record("Expected turnStart")
        }
    }

    @Test func playerEliminatedCodable() throws {
        let msg = GameMessage.playerEliminated(playerID: "p1", playerName: "Alice")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .playerEliminated(let id, let name) = decoded {
            #expect(id == "p1")
            #expect(name == "Alice")
        } else {
            Issue.record("Expected playerEliminated")
        }
    }

    @Test func gameOverCodable() throws {
        let standings = [Player(displayName: "W"), Player(displayName: "L")]
        let msg = GameMessage.gameOver(winnerID: "w1", winnerName: "Winner", standings: standings)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .gameOver(let wid, let wname, let s) = decoded {
            #expect(wid == "w1")
            #expect(wname == "Winner")
            #expect(s.count == 2)
        } else {
            Issue.record("Expected gameOver")
        }
    }

    @Test func returnToLobbyCodable() throws {
        let roster = [Player(displayName: "A")]
        let msg = GameMessage.returnToLobby(roster: roster)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .returnToLobby(let r) = decoded {
            #expect(r.count == 1)
        } else {
            Issue.record("Expected returnToLobby")
        }
    }

    @Test func gameCountdownCodable() throws {
        let msg = GameMessage.gameCountdown(remaining: 3)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        if case .gameCountdown(let r) = decoded {
            #expect(r == 3)
        } else {
            Issue.record("Expected gameCountdown")
        }
    }
}

// MARK: - GameState Tests

@MainActor
struct GameStateTests {
    @Test func initialState() {
        let state = GameState()
        #expect(state.phase == .lobby)
        #expect(state.difficulty == .standard)
        #expect(state.players.isEmpty)
        #expect(state.localPlayer == nil)
        #expect(state.isHost == false)
        #expect(state.activePlayerID == nil)
        #expect(state.turnDuration == 3.0)
        #expect(state.turnStartDate == nil)
        #expect(state.eliminationStandings.isEmpty)
        #expect(state.errorMessage == nil)
    }

    @Test func isMyTurnWhenActive() {
        let state = GameState()
        let player = Player(displayName: "Me")
        state.localPlayer = player
        state.players = [player]
        state.activePlayerID = player.id
        #expect(state.isMyTurn == true)
    }

    @Test func isMyTurnWhenNotActive() {
        let state = GameState()
        let me = Player(displayName: "Me")
        let other = Player(displayName: "Other")
        state.localPlayer = me
        state.players = [me, other]
        state.activePlayerID = other.id
        #expect(state.isMyTurn == false)
    }

    @Test func isMyTurnWhenEliminated() {
        let state = GameState()
        var player = Player(displayName: "Me")
        state.localPlayer = player
        player.isEliminated = true
        state.players = [player]
        state.activePlayerID = player.id
        #expect(state.isMyTurn == false)
    }

    @Test func isMyTurnWhenNoLocalPlayer() {
        let state = GameState()
        state.activePlayerID = "some-id"
        #expect(state.isMyTurn == false)
    }

    @Test func activePlayers() {
        let state = GameState()
        var p1 = Player(displayName: "A")
        var p2 = Player(displayName: "B")
        let p3 = Player(displayName: "C")
        p1.isEliminated = true
        p2.isEliminated = false
        state.players = [p1, p2, p3]
        #expect(state.activePlayers.count == 2)
        #expect(state.activePlayers.contains(where: { $0.id == p2.id }))
        #expect(state.activePlayers.contains(where: { $0.id == p3.id }))
    }

    @Test func activePlayersAllEliminated() {
        let state = GameState()
        var p1 = Player(displayName: "A")
        p1.isEliminated = true
        var p2 = Player(displayName: "B")
        p2.isEliminated = true
        state.players = [p1, p2]
        #expect(state.activePlayers.isEmpty)
    }

    @Test func reset() {
        let state = GameState()
        var p1 = Player(displayName: "A")
        p1.isEliminated = true
        let p2 = Player(displayName: "B")
        state.players = [p1, p2]
        state.phase = .playing
        state.activePlayerID = "some-id"
        state.turnDuration = 1.5
        state.turnStartDate = Date()
        state.eliminationStandings = [p1]

        state.reset()

        #expect(state.phase == .lobby)
        #expect(state.activePlayerID == nil)
        #expect(state.turnDuration == 3.0)
        #expect(state.turnStartDate == nil)
        #expect(state.eliminationStandings.isEmpty)
        // Players should remain but be un-eliminated
        #expect(state.players.count == 2)
        #expect(state.players.allSatisfy { !$0.isEliminated })
    }

    @Test func resetPreservesPlayerList() {
        let state = GameState()
        let p1 = Player(displayName: "Host", isHost: true)
        let p2 = Player(displayName: "Client")
        state.players = [p1, p2]
        state.reset()
        #expect(state.players.count == 2)
        #expect(state.players[0].displayName == "Host")
    }
}

// MARK: - ClientMessageHandler Tests

@MainActor
struct ClientMessageHandlerTests {
    private func makeHandler() -> (GameState, MultipeerService, ClientMessageHandler) {
        let state = GameState()
        let service = MultipeerService()
        let handler = ClientMessageHandler(gameState: state, multipeerService: service)
        handler.setupMessageHandling()
        return (state, service, handler)
    }

    @Test func joinAcceptedUpdatesState() {
        let (state, service, _) = makeHandler()
        let player = Player(displayName: "Me")
        let roster = [Player(displayName: "Host", isHost: true), player]
        let msg = GameMessage.joinAccepted(yourPlayer: player, roster: roster)
        // Simulate receiving message by calling the handler directly
        service.onMessageReceived?(msg, MockPeerID.peer1)

        #expect(state.localPlayer?.id == player.id)
        #expect(state.players.count == 2)
    }

    @Test func joinRejectedClearsPlayer() {
        let (state, service, _) = makeHandler()
        state.localPlayer = Player(displayName: "Me")
        let msg = GameMessage.joinRejected(reason: "Game is full")
        service.onMessageReceived?(msg, MockPeerID.peer1)

        #expect(state.localPlayer == nil)
        #expect(state.errorMessage == "Game is full")
        #expect(state.phase == .lobby)
    }

    @Test func lobbyUpdateSyncsRoster() {
        let (state, service, _) = makeHandler()
        let roster = [Player(displayName: "A"), Player(displayName: "B"), Player(displayName: "C")]
        service.onMessageReceived?(.lobbyUpdate(roster: roster), MockPeerID.peer1)

        #expect(state.players.count == 3)
    }

    @Test func gameStartSetsDifficulty() {
        let (state, service, _) = makeHandler()
        service.onMessageReceived?(.gameStart(difficulty: "hard"), MockPeerID.peer1)
        #expect(state.difficulty == .hard)
    }

    @Test func gameStartInvalidDifficultyIgnored() {
        let (state, service, _) = makeHandler()
        state.difficulty = .standard
        service.onMessageReceived?(.gameStart(difficulty: "impossible"), MockPeerID.peer1)
        #expect(state.difficulty == .standard)
    }

    @Test func gameCountdownUpdatesPhase() {
        let (state, service, _) = makeHandler()
        service.onMessageReceived?(.gameCountdown(remaining: 3), MockPeerID.peer1)
        #expect(state.phase == .countdown(remaining: 3))
    }

    @Test func turnStartUpdatesActivePlayer() {
        let (state, service, _) = makeHandler()
        service.onMessageReceived?(.turnStart(activePlayerID: "p1", duration: 2.5), MockPeerID.peer1)

        #expect(state.phase == .playing)
        #expect(state.activePlayerID == "p1")
        #expect(state.turnDuration == 2.5)
        #expect(state.turnStartDate != nil)
    }

    @Test func playerEliminatedMarksPlayer() {
        let (state, service, _) = makeHandler()
        let p1 = Player(id: "p1", displayName: "Alice")
        let p2 = Player(id: "p2", displayName: "Bob")
        state.players = [p1, p2]

        service.onMessageReceived?(.playerEliminated(playerID: "p1", playerName: "Alice"), MockPeerID.peer1)

        #expect(state.players.first(where: { $0.id == "p1" })?.isEliminated == true)
        #expect(state.players.first(where: { $0.id == "p2" })?.isEliminated == false)
        #expect(state.eliminationStandings.count == 1)
        #expect(state.phase == .elimination(eliminatedPlayerID: "p1", eliminatedPlayerName: "Alice"))
    }

    @Test func gameOverSetsPhaseAndStandings() {
        let (state, service, _) = makeHandler()
        let standings = [Player(displayName: "W"), Player(displayName: "L")]
        service.onMessageReceived?(
            .gameOver(winnerID: "w1", winnerName: "Winner", standings: standings),
            MockPeerID.peer1
        )

        #expect(state.phase == .gameOver(winnerName: "Winner"))
        #expect(state.eliminationStandings.count == 2)
    }

    @Test func returnToLobbyResetsState() {
        let (state, service, _) = makeHandler()
        var p1 = Player(displayName: "A")
        p1.isEliminated = true
        state.players = [p1]
        state.activePlayerID = "some-id"
        state.turnStartDate = Date()
        state.eliminationStandings = [p1]
        state.phase = .gameOver(winnerName: "A")

        let freshRoster = [Player(displayName: "A"), Player(displayName: "B")]
        service.onMessageReceived?(.returnToLobby(roster: freshRoster), MockPeerID.peer1)

        #expect(state.phase == .lobby)
        #expect(state.players.count == 2)
        #expect(state.players.allSatisfy { !$0.isEliminated })
        #expect(state.activePlayerID == nil)
        #expect(state.turnStartDate == nil)
        #expect(state.eliminationStandings.isEmpty)
    }
}

// MARK: - GameManager Tests

@MainActor
struct GameManagerTests {
    private func makeGameManager() -> (GameState, MultipeerService, GameManager) {
        let state = GameState()
        let service = MultipeerService()
        let manager = GameManager(multipeerService: service, gameState: state)
        return (state, service, manager)
    }

    @Test func setupAsHost() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)

        #expect(state.isHost == true)
        #expect(state.localPlayer?.id == host.id)
        #expect(state.players.count == 1)
        #expect(state.players[0].isHost == true)
        #expect(state.phase == .lobby)
    }

    @Test func addBot() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)

        manager.addBot()
        #expect(state.players.count == 2)
        #expect(manager.botPlayers.count == 1)
        #expect(manager.botEnabled == true)
    }

    @Test func addBotMaxPlayers() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)

        // Add 4 bots to fill game (host + 4 = 5)
        for _ in 0..<4 {
            manager.addBot()
        }
        #expect(state.players.count == 5)

        // Adding another should be rejected
        manager.addBot()
        #expect(state.players.count == 5)
    }

    @Test func removeBot() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)

        manager.addBot()
        manager.addBot()
        #expect(state.players.count == 3)
        #expect(manager.botPlayers.count == 2)

        manager.removeBot()
        #expect(state.players.count == 2)
        #expect(manager.botPlayers.count == 1)
    }

    @Test func removeBotWhenNone() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)

        manager.removeBot()
        #expect(state.players.count == 1) // No change
    }

    @Test func startGameRequiresMinPlayers() async {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)

        // Only 1 player, should not start
        manager.startGame()
        #expect(state.phase == .lobby)

        // Add a bot and try again
        manager.addBot()
        manager.startGame()
        // Phase is set inside an async Task — yield to let it run
        try? await Task.sleep(for: .milliseconds(50))
        #expect(state.phase == .countdown(remaining: 3))
    }

    @Test func startGameResetsEliminations() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)
        manager.addBot()

        // Manually mark host as eliminated
        state.players[0].isEliminated = true
        state.eliminationStandings = [state.players[0]]

        manager.startGame()
        #expect(state.players.allSatisfy { !$0.isEliminated })
        #expect(state.eliminationStandings.isEmpty)
    }

    @Test func handleTapIgnoresWrongPlayer() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)
        manager.addBot()

        state.phase = .playing
        state.activePlayerID = host.id

        // Wrong player tapping should be ignored
        manager.handleTap(playerID: "wrong-id")
        #expect(state.activePlayerID == host.id) // unchanged
    }

    @Test func handleTapIgnoresWhenNotPlaying() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)

        state.phase = .lobby
        state.activePlayerID = host.id

        manager.handleTap(playerID: host.id)
        // Should be ignored since phase is lobby
        #expect(state.phase == .lobby)
    }

    @Test func returnToLobbyResetsState() {
        let (state, _, manager) = makeGameManager()
        let host = Player(displayName: "Host", isHost: true)
        manager.setupAsHost(localPlayer: host)
        manager.addBot()

        state.phase = .playing
        state.activePlayerID = host.id
        state.turnStartDate = Date()

        manager.returnToLobby()

        #expect(state.phase == .lobby)
        #expect(state.activePlayerID == nil)
        #expect(state.turnStartDate == nil)
        #expect(state.eliminationStandings.isEmpty)
        #expect(manager.botPlayers.isEmpty) // Bots cleared
    }
}

// MARK: - Mock Helpers

/// Lightweight mock peer ID namespace for testing callbacks
/// Note: MCPeerID requires MultipeerConnectivity which may not be available in test targets.
/// These tests use the onMessageReceived callback directly.
import MultipeerConnectivity

enum MockPeerID {
    static let peer1 = MCPeerID(displayName: "TestPeer1")
    static let peer2 = MCPeerID(displayName: "TestPeer2")
    static let peer3 = MCPeerID(displayName: "TestPeer3")
}
