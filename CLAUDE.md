# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A multiplayer co-op Minesweeper built with Flutter (Dart). Players either host a game over LAN (mDNS discovery + a local WebSocket server) or over the internet (a short room code routed through a Cloudflare Worker relay). One team works the same board together with shared reveals, flags, cursors, emoji, and chat. Targets Android, Windows, and web.

## Commands

```sh
flutter pub get                        # install deps
flutter run                            # run on the default device
flutter analyze                        # lint (uses analysis_options.yaml → flutter_lints)
flutter test                           # run all tests
flutter test test/engine_test.dart     # run a single test file
flutter test --name "substring"        # run tests whose name matches

# Codegen (freezed / json_serializable). Run after touching annotated models.
dart run build_runner build --delete-conflicting-outputs

# Release builds MUST pass the relay URL in, or online play is disabled at runtime:
flutter build windows --release --dart-define=RELAY_URL=wss://minesweeper-relay.lacon.workers.dev
flutter build apk     --release --dart-define=RELAY_URL=wss://minesweeper-relay.lacon.workers.dev

dart run flutter_launcher_icons        # regenerate app icons from assets/icon/icon.png
```

The relay (`relay/`, a separate Node/TypeScript Cloudflare Worker project):

```sh
cd relay
npm install
npm run dev        # local relay on http://localhost:8787
npm run deploy     # wrangler deploy
npm run tail       # live logs
```

## Architecture

### Authoritative host model

There is exactly one source of truth per match: the **host's `GameEngine`** (`lib/game/engine.dart`). Guests never run game logic — they only render server messages. Critically, **the host plays through the same code path as a guest**: the host UI subscribes to `HostSession.localEvents`, a stream that emits the identical `ServerMessage`s guests receive over the wire. So host and guest rendering are one code path; only the input side differs (`SessionNotifier._send` routes a local host intent straight into `HostSession.onLocalIntent`, vs. a guest's transport send).

The layers, top to bottom:

- **UI** (`lib/ui/`) — screens (`home`, `host_lobby`, `browse`, `join`, `game`, `result`) wired by `lib/app/router.dart` (go_router). Widgets in `lib/ui/widgets/`.
- **State** (`lib/state/`) — Riverpod notifiers. `session.dart` is the hub: `SessionNotifier` owns either a `HostSession` (if hosting) or a `GuestTransport` (if joined), and reduces every incoming `ServerMessage` into an immutable `GameSnapshot` that the UI watches. `chat.dart` is a separate provider fed from `SChat`.
- **Host session** (`lib/state/host_session.dart`) — only exists on the host. Owns the `GameEngine`, the player roster, and the logical↔transport id mapping for reconnect. Converts inbound `ClientMessage`s into engine calls and broadcasts the resulting `ServerMessage`s.
- **Game core** (`lib/game/`) — pure Dart, no I/O. `board.dart` (cells, flood-fill reveal, chord, auto-flag, Hearts-mode chain explosions), `engine.dart` (status, stats, win/lose), `difficulty.dart` (`GameConfig`, `Difficulty`, `GameMode`).
- **Net** (`lib/net/`) — transports and the wire protocol.

### Transport seam

`lib/net/transport.dart` defines two abstract interfaces — `HostTransport` and `GuestTransport` — that are pure pipes: they decode/encode the protocol envelope but know nothing about game logic. Two concrete implementations of each:

- **LAN**: `LanHostTransport` / `LanGuestTransport` (in `server_io.dart`, behind the conditional export in `server.dart`). The host runs a `shelf` WebSocket server; discovery via `nsd` (mDNS) in `discovery_io.dart`.
- **Online**: `RelayHostTransport` / `RelayGuestTransport` (`relay_transport.dart`). Both ends open a single WebSocket to the Cloudflare relay; the relay routes opaque payloads by room code and never parses the game protocol.

`server.dart`, `discovery.dart`, and `local_ip.dart` each use the `export 'x_stub.dart' if (dart.library.io) 'x_io.dart'` pattern so the web build (no `dart:io`) compiles against stubs. **When adding platform-dependent networking, follow this stub/io split or the web build breaks.**

`HostSession` is transport-agnostic — it's constructed with whichever `HostTransport` matches `HostMode.lan`/`HostMode.online`. Same for the guest side.

### Wire protocol

`lib/net/messages.dart` is the single protocol definition, used identically by LAN and relay. `ClientMessage` (guest→host) and `ServerMessage` (host→guest) are sealed classes; each `encode()`s to `{"t": type, "d": payload}` and decodes via a `switch`. Key conventions when changing it:

- **`protocolVersion`** (currently 6) — bump on a breaking change. Read the doc comment for the version history (e.g. v4 packed `SRevealed.cells` into flat `[x,y,v,...]` triplets; v6 added the moderation messages).
- **Forward compatibility**: an unknown `t` decodes to `CUnknown`/`SUnknown` (ignored), never throws. This lets a newer peer add messages without dropping the connection. Preserve this — decoders must not throw on unknown types.
- **Backward compatibility**: decoders accept legacy shapes (e.g. `_decodeReveals` reads both packed triplets and old map arrays; `SFlagged` keeps a legacy `flagged` bool alongside `mark`). Keep both when evolving a message.
- The cell encoding `-2 hidden, -1 mine, 0..8 number` is shared between `GameSnapshot.cells` and `SSnapshot.cells`.

### Reconnect / presence (the subtle part)

Both sides survive socket drops:

- **Logical vs transport ids**: a guest gets a fresh transport id on every (re)connect, but their *logical* player id (used for board ownership, stats, color) must be stable. `HostSession` keeps `_transportToLogical` / `_logicalToTransport` maps. On disconnect the player is marked `isOffline` and held for a 30s **grace window** (`_graceTimers`) before eviction.
- **Rejoin token**: the guest mints a `_rejoinToken` once per join (`SessionNotifier`) and resends it in `CJoin` on every reconnect. If the host still holds that token within the grace window, it rebinds the new transport to the old logical id, restores the slot, and replays state via `SSnapshot` (full mid-game board catch-up). Tokens are echoed back in `SSnapshot.rejoinToken`.
- **Guest reconnect loop**: `SessionNotifier._attemptConnect` / `_scheduleReconnect` with backoff `[1,2,4,8,8,8]`s; cut short when the app returns to foreground (`_onAppResumed`).
- **Online host reclaim**: the relay holds the room open in its own grace window if the *host* drops. `RelayHostTransport` reclaims via `/reclaim/<code>?token=<hostToken>` with the same backoff, surfacing `reclaiming`/`reclaimed` transport errors that `HostSession` translates into `SHostAway`/`SHostBack`. Guests see those and re-send `CJoin`.
- **Liveness**: guests `CPing` every ~8s; host replies `SPong` (filtered inside the relay transport, never surfaced to the session). Both sides force-close a half-open socket after a dead-timeout.

When touching join/reconnect, trace the full path: `CJoin` → `HostSession._handleJoin` → token lookup → `_bindTransport` → `SWelcome` (with the *logical* id) → `SLobby` → `_sendMidGameSnapshot`.

### Moderation / user-generated content

The app carries UGC (display names, chat, avatar photos) between strangers, so it
ships the safety tools Google Play's UGC policy requires. Three independent
mechanisms, deliberately at different layers:

- **Filtering — host-side, authoritative.** `lib/core/moderation.dart` folds
  leetspeak, accents, zero-width padding, and repeat-runs before matching against
  two lists: `_blockedAnywhere` (substring-safe, catches `f.u.c.k`) and
  `_blockedWords` (whole-token only, so `grass` and `analysis` survive). Applied
  in `HostSession` to every `CJoin` name and every `CChat` line *before*
  broadcast, so a patched client can't push raw text to the room.
- **Blocking — client-side, local.** `lib/state/moderation.dart`. The host owns
  who's in the room; each player owns what they see. Blocked authors are dropped
  in `SessionNotifier._handleServerMessage` at receive time (chat, emoji,
  cursor) rather than hidden at paint time, so nothing leaks into the unread
  badge or the toast preview. Keyed by logical id (exact, room-scoped) *and*
  folded display name (fuzzy, persisted) — there are no accounts, so neither
  alone is enough.
- **Kick / report — protocol.** `CKick`/`SKicked` and
  `CReport`/`SReportAck`/`SModerationNotice` (v6). `HostSession._handleKick`
  removes the player from `_players` itself rather than waiting on the
  transport's disconnect event, bans their rejoin token for the life of the
  room, and evicts via `HostTransport.disconnectGuest`. `SKicked` puts the guest
  into `SessionConnState.kicked`, which cancels the reconnect loop — retrying
  would be futile since the token is banned.

UI entry points: `showPlayerActions()` in `lib/ui/widgets/player_actions.dart`,
reachable from the lobby slots, the in-game player bar, join-screen chips, and
chat bubbles (long-press). `ModerationListener` surfaces incoming reports to the
host. `/safety` lists blocked players and filed reports.

**When adding any surface that displays another player's name, photo, or text,
wire `showPlayerActions` into it and honour `blockedPlayersProvider`.** Play
treats an unreachable report control as no report control.

### Game modes

`GameMode.classic` (any mine ends the game) and `GameMode.hearts` (team shares N hearts; a mine triggers a chain explosion revealing its 3×3 neighborhood and chaining through adjacent mines up to `Board.chainMaxMines`; one trigger click costs one heart regardless of chain size). Mine placement is deterministic from a `seed` with a 3×3 first-click safe zone (`Board.placeMines`). Flag accuracy is computed once at game-end (`_finalizeFlagAccuracy`), not per toggle, to avoid desync.

### Relay internals

`relay/src/worker.ts` is the router (generates Crockford-base32 codes, maps each to a Durable Object); `relay/src/room.ts` is the per-room Durable Object that fans out frames between the one host and up to 7 guests. See `relay/README.md` for the full envelope table. The relay is intentionally protocol-blind — it forwards the `msg` string verbatim.

## Conventions

- State objects (`GameSnapshot`, `SessionState`, `PlayerInfo`, `GameConfig`) are immutable with `copyWith`; reducers build a new snapshot rather than mutating.
- `lib/core/ids.dart` `shortId()` generates player/room/token ids.
- The app uses a single shared `AmbientBackground` behind transparent scaffolds (see `main.dart`). Per memory: keep gameplay/board visuals as-is; backgrounds should stay flat/calm, not gradient-heavy.
