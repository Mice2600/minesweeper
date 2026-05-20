# Minesweeper Relay

A tiny WebSocket relay so two devices on different networks can host/join a Minesweeper game using a short room code.

The relay is a Cloudflare Worker backed by a Durable Object per room. It does **not** parse the game protocol — it only routes opaque JSON between the host and its guests. The host's `GameEngine` remains the sole source of truth.

## Run locally

```sh
cd relay
npm install
npm run dev          # serves on http://localhost:8787
```

Smoke test with `wscat`:

```sh
# Host
wscat -c ws://localhost:8787/create
# → {"kind":"control","op":"created","code":"Q7K9M"}

# Guest (in another shell)
wscat -c ws://localhost:8787/join/Q7K9M
# → {"kind":"control","op":"joined","id":"abc123"}
# Host also receives:    {"kind":"control","op":"joined","id":"abc123"}

# Guest sends to host
> {"kind":"to-host","msg":"{\"t\":\"join\",\"d\":{\"name\":\"alice\",\"avatarSeed\":\"x\"}}"}
# Host receives:         {"kind":"from-guest","from":"abc123","msg":"..."}
```

## Deploy

```sh
npm run deploy
```

Wrangler will print the URL (`https://minesweeper-relay.<your-subdomain>.workers.dev`). Use it as `wss://...workers.dev` in the Flutter app via `--dart-define=RELAY_URL=wss://...`.

## Protocol summary

Outer envelope:

| Direction | Frame |
| --- | --- |
| Host → relay | `{kind:"to-guest", to:"<pid>", msg:"<server-msg-json>"}` |
| Host → relay | `{kind:"to-all", msg:"<server-msg-json>"}` |
| Host → relay | `{kind:"kick", to:"<pid>"}` |
| Guest → relay | `{kind:"to-host", msg:"<client-msg-json>"}` |
| Relay → host | `{kind:"control", op:"created", code:"XXXXX"}` (once on connect) |
| Relay → host | `{kind:"control", op:"joined" \| "left", id:"<pid>"}` |
| Relay → host | `{kind:"from-guest", from:"<pid>", msg:"<client-msg-json>"}` |
| Relay → guest | `{kind:"control", op:"joined", id:"<pid>"}` (once on connect) |
| Relay → guest | `{kind:"from-host", msg:"<server-msg-json>"}` |
| Relay → guest | `{kind:"control", op:"host-left"}` (room closes) |
| Relay → either | `{kind:"control", op:"error", code:"...", message:"..."}` |

`msg` is always a JSON string (the existing Minesweeper protocol envelope `{"t":..,"d":..}`). The relay never decodes it.

## Limits

- 1 host + up to 7 guests per room (covers the app's `_maxPlayers = 4` with reconnect slack).
- Codes are 5 chars in Crockford base32 (no I/L/O/U). ~33M possible.
- No persistence: if the host disconnects, the room is dropped after a 30-second grace window.
