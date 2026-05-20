/// <reference types="@cloudflare/workers-types" />

// Outer envelope routed by the relay. Inner `msg` is opaque (the existing
// Minesweeper protocol JSON).
//
//   Host  → relay : { kind: "to-guest", to: "<pid>", msg: "<ServerMessage>" }
//                   { kind: "to-all",                 msg: "<ServerMessage>" }
//                   { kind: "kick",     to: "<pid>" }
//   Guest → relay : { kind: "to-host",                msg: "<ClientMessage>" }
//   Relay → host  : { kind: "control",  op: "joined" | "left", id: "<pid>" }
//                   { kind: "from-guest", from: "<pid>", msg: "<ClientMessage>" }
//   Relay → guest : { kind: "from-host", msg: "<ServerMessage>" }
//                   { kind: "control",  op: "host-away" }   ← grace window
//                   { kind: "control",  op: "host-back" }   ← reclaim landed
//                   { kind: "control",  op: "host-left" }   ← grace expired
//   Relay → host  on create  : { kind: "control", op: "created",   code, hostToken }
//   Relay → host  on reclaim : { kind: "control", op: "reclaimed", code, hostToken }
//   Relay → either on error  : { kind: "control", op: "error", code, message }

const MAX_GUESTS = 7; // host + 7 guests covers _maxPlayers=4 with reconnect slack
const HOST_GRACE_MS = 60_000; // window for host /reclaim before room is dropped

interface GuestRecord {
  ws: WebSocket;
  id: string;
}

export class Room implements DurableObject {
  private code = "";
  private host: WebSocket | null = null;
  private hostToken: string | null = null;
  private guests = new Map<string, GuestRecord>();
  private destroyTimer: number | null = null;

  constructor(_state: DurableObjectState, _env: unknown) {}

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const hostMatch = url.pathname.match(/^\/host\/([A-Z0-9]+)$/);
    const reclaimMatch = url.pathname.match(/^\/reclaim-do\/([A-Z0-9]+)$/);
    const guestMatch = url.pathname.match(/^\/guest\/([A-Z0-9]+)$/);

    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket", { status: 426 });
    }

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    server.accept();

    if (hostMatch) {
      this.code = hostMatch[1];
      this.attachHost(server);
    } else if (reclaimMatch) {
      this.code = reclaimMatch[1];
      const token = url.searchParams.get("token") ?? "";
      this.attachReclaim(server, token);
    } else if (guestMatch) {
      this.attachGuest(server);
    } else {
      server.close(1008, "bad path");
      return new Response("Bad path", { status: 400 });
    }

    return new Response(null, { status: 101, webSocket: client });
  }

  // ─── Host lifecycle ───────────────────────────────────────────────────────

  private attachHost(ws: WebSocket): void {
    if (this.host !== null) {
      // Someone is already host. Reject — the proper recovery path is the
      // /reclaim endpoint with the hostToken.
      ws.send(
        JSON.stringify({
          kind: "control",
          op: "error",
          code: "host-taken",
          message: "Host socket already attached",
        }),
      );
      ws.close(1008, "host taken");
      return;
    }
    if (this.hostToken !== null) {
      // The room already has a host token, meaning a previous host is in the
      // grace window. Force them to reclaim with their token instead of
      // overwriting the room.
      ws.send(
        JSON.stringify({
          kind: "control",
          op: "error",
          code: "host-grace",
          message: "Room is in host-grace — use /reclaim with the hostToken",
        }),
      );
      ws.close(1008, "host grace");
      return;
    }
    this.hostToken = shortId(20);
    this.host = ws;
    this.cancelDestroy();
    ws.send(
      JSON.stringify({
        kind: "control",
        op: "created",
        code: this.code,
        hostToken: this.hostToken,
      }),
    );
    this.wireHostHandlers(ws);
  }

  private attachReclaim(ws: WebSocket, token: string): void {
    if (this.hostToken === null || token !== this.hostToken) {
      ws.send(
        JSON.stringify({
          kind: "control",
          op: "error",
          code: "bad-token",
          message: "Reclaim token does not match this room",
        }),
      );
      ws.close(1008, "bad token");
      return;
    }
    // If an old host socket is still hanging on, drop it now — we trust the
    // caller of /reclaim (they had the token) over a stale half-open.
    if (this.host !== null) {
      try {
        this.host.close(1000, "reclaimed");
      } catch {}
      this.host = null;
    }
    this.host = ws;
    this.cancelDestroy();
    ws.send(
      JSON.stringify({
        kind: "control",
        op: "reclaimed",
        code: this.code,
        hostToken: this.hostToken,
      }),
    );
    // Catch the host up on the current guest list so its HostSession can
    // re-bind transport ids.
    for (const g of this.guests.values()) {
      ws.send(JSON.stringify({ kind: "control", op: "joined", id: g.id }));
    }
    // Tell every guest the host is back — they'll re-send CJoin with their
    // rejoin token, which the host turns into an in-place restore.
    for (const g of this.guests.values()) {
      this.safeSend(g.ws, { kind: "control", op: "host-back" });
    }
    this.wireHostHandlers(ws);
  }

  private wireHostHandlers(ws: WebSocket): void {
    ws.addEventListener("message", (ev: MessageEvent) =>
      this.onHostMessage(ev),
    );
    ws.addEventListener("close", () => this.onHostClose());
    ws.addEventListener("error", () => this.onHostClose());
  }

  private onHostMessage(ev: MessageEvent): void {
    let frame: any;
    try {
      frame = JSON.parse(typeof ev.data === "string" ? ev.data : "");
    } catch {
      return;
    }
    if (!frame || typeof frame !== "object") return;
    switch (frame.kind) {
      case "to-guest": {
        const g = this.guests.get(frame.to);
        if (g) {
          this.safeSend(g.ws, { kind: "from-host", msg: frame.msg });
        }
        break;
      }
      case "to-all": {
        for (const g of this.guests.values()) {
          this.safeSend(g.ws, { kind: "from-host", msg: frame.msg });
        }
        break;
      }
      case "kick": {
        const g = this.guests.get(frame.to);
        if (g) {
          try {
            g.ws.close(1000, "kicked");
          } catch {}
          this.guests.delete(frame.to);
        }
        break;
      }
      default:
        // ignore unknown
        break;
    }
  }

  private onHostClose(): void {
    this.host = null;
    // Don't evict guests — give the host a chance to /reclaim within the
    // grace window. Guests just see a "host-away" badge and wait.
    for (const g of this.guests.values()) {
      this.safeSend(g.ws, { kind: "control", op: "host-away" });
    }
    this.scheduleDestroy();
  }

  // ─── Guest lifecycle ──────────────────────────────────────────────────────

  private attachGuest(ws: WebSocket): void {
    // Room must have been created at some point. If we have no hostToken on
    // file, the relay has no idea what this room is.
    if (this.hostToken === null) {
      ws.send(
        JSON.stringify({
          kind: "control",
          op: "error",
          code: "no-room",
          message: "Room not found",
        }),
      );
      ws.close(1008, "no room");
      return;
    }
    if (this.guests.size >= MAX_GUESTS) {
      ws.send(
        JSON.stringify({
          kind: "control",
          op: "error",
          code: "full",
          message: "Room is full",
        }),
      );
      ws.close(1008, "full");
      return;
    }
    const id = shortId();
    this.guests.set(id, { ws, id });
    // Tell the guest their assigned id.
    ws.send(JSON.stringify({ kind: "control", op: "joined", id }));
    // Tell the host a guest joined — or, if host is in grace, tell the new
    // guest the host is away so they show a banner instead of staring at a
    // dead lobby.
    if (this.host !== null) {
      this.safeSend(this.host, { kind: "control", op: "joined", id });
    } else {
      this.safeSend(ws, { kind: "control", op: "host-away" });
    }

    ws.addEventListener("message", (ev: MessageEvent) =>
      this.onGuestMessage(id, ev),
    );
    ws.addEventListener("close", () => this.onGuestClose(id));
    ws.addEventListener("error", () => this.onGuestClose(id));
  }

  private onGuestMessage(id: string, ev: MessageEvent): void {
    let frame: any;
    try {
      frame = JSON.parse(typeof ev.data === "string" ? ev.data : "");
    } catch {
      return;
    }
    if (!frame || typeof frame !== "object") return;
    // Guests are only allowed to send to the host.
    if (frame.kind !== "to-host") return;
    if (this.host === null) {
      // Host away — drop silently. The guest will re-send CJoin on host-back
      // so authoritative state catches up via the rejoin path.
      return;
    }
    this.safeSend(this.host, {
      kind: "from-guest",
      from: id,
      msg: frame.msg,
    });
  }

  private onGuestClose(id: string): void {
    if (!this.guests.delete(id)) return;
    if (this.host) {
      this.safeSend(this.host, { kind: "control", op: "left", id });
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  private safeSend(ws: WebSocket, frame: unknown): void {
    try {
      ws.send(JSON.stringify(frame));
    } catch {
      // socket gone — let the close handler clean up
    }
  }

  private scheduleDestroy(): void {
    this.cancelDestroy();
    this.destroyTimer = setTimeout(() => {
      this.destroyTimer = null;
      if (this.host !== null) return; // host returned in time
      // Grace expired. Now we evict guests for real.
      for (const g of this.guests.values()) {
        this.safeSend(g.ws, { kind: "control", op: "host-left" });
        try {
          g.ws.close(1000, "host left");
        } catch {}
      }
      this.guests.clear();
      this.hostToken = null;
    }, HOST_GRACE_MS) as unknown as number;
  }

  private cancelDestroy(): void {
    if (this.destroyTimer !== null) {
      clearTimeout(this.destroyTimer);
      this.destroyTimer = null;
    }
  }
}

const ID_ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789";
function shortId(len = 6): string {
  const bytes = new Uint8Array(len);
  crypto.getRandomValues(bytes);
  let out = "";
  for (let i = 0; i < len; i++) {
    out += ID_ALPHABET[bytes[i] % ID_ALPHABET.length];
  }
  return out;
}
