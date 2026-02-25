# Rallywreck

A local multiplayer party game for iOS where players take turns tapping a button before time runs out. Last player standing wins.

## Tech Stack

- **Swift / SwiftUI** — iOS 26.2 deployment target
- **MultipeerConnectivity** — peer-to-peer local multiplayer (host/client model)
- **AVFoundation** — custom synth engine for sound effects
- **Observation** (`@Observable`) — state management
- Zero external dependencies

## Architecture

State-driven, phase-based navigation:

- `GameState` is the single source of truth (`@Observable`). Views observe it, events flow up through `GameManager`.
- `ContentView` switches screens based on `gameState.phase` (lobby → countdown → playing → elimination → gameOver).
- `GameManager` (`@MainActor`) runs host-side logic: turns, timers, elimination, bot AI.
- `MultipeerService` wraps MCSession. Callbacks dispatch to `@MainActor` via `Task { @MainActor in }`.
- `ClientMessageHandler` routes incoming `GameMessage`s to `GameState` updates on non-host devices.
- `SynthEngine` does real-time audio synthesis with `os_unfair_lock` for thread-safe render-thread access.

## Project Structure

```
Rallywreck/
  Models/          Player, GameState, GamePhase, GameMessage (structs/enums, Codable)
  Views/           HomeView, LobbyView, GameView, GameOverView (one screen per file)
  Views/Components/ EliminationOverlay, PlayerLeftOverlay, TimerBarView, etc.
  Services/        GameManager, MultipeerService, ClientMessageHandler, SynthEngine
  Theme/           NeonTheme (colors, fonts, spacing constants)
  RallywreckApp.swift  App entry point (eager init of all state/services)
  ContentView.swift    Root view (phase-based navigation switch)
```

## Build & Test

```bash
# Build
xcodebuild build -scheme Rallywreck -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'

# Test
xcodebuild test -scheme Rallywreck -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing RallywreckTests -parallel-testing-enabled NO
```

## Conventions

- **Models are structs** (`Player`, `GamePhase`, `GameMessage`), **state containers are `@Observable` classes** (`GameState`, `GameManager`, `MultipeerService`, `SynthEngine`).
- **`@MainActor`** on `GameManager` — all Tasks that mutate game state serialize on main actor.
- **Weak self** in MultipeerService closures to prevent retain cycles.
- **Task cancellation** — all long-running Tasks are stored and cancelled on teardown (`countdownTask`, `turnTimer`, `botTimer`, `eliminationTimer`).
- **NeonTheme** for all colors/fonts — never use raw Color/Font literals in views.
- **`// MARK: -`** sections to organize code within files.
- **Guard-early-return** pattern throughout GameManager.
- **`@AppStorage("playerName")`** persists username across sessions.

## Network Model

- Host browses, clients advertise. Host invites discovered peers.
- `GameMessage` (Codable enum) is the only wire format. Sent as JSON via `MCSession.send`.
- Client sends taps only to host peer (not `sendToAll`).
- Host broadcasts state changes to all connected peers.
- `peerToPlayerID` / `playerIDToPeer` maps maintain MC peer ↔ game player mapping.

## Testing

- Apple Testing framework (Swift 6+), 59 tests across 7 suites.
- Tests cover: Player, Difficulty, GamePhase, GameMessage (codability), GameState (turns, elimination), ClientMessageHandler (message routing), GameManager (host logic).
- No external test dependencies.
