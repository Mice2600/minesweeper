/// <reference types="@cloudflare/workers-types" />

export { Room } from "./room";

interface Env {
  ROOM: DurableObjectNamespace;
}

// Crockford base32 (no I, L, O, U) so codes are unambiguous out loud.
const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const CODE_LEN = 5;

function randomCode(): string {
  const bytes = new Uint8Array(CODE_LEN);
  crypto.getRandomValues(bytes);
  let out = "";
  for (let i = 0; i < CODE_LEN; i++) {
    out += ALPHABET[bytes[i] % ALPHABET.length];
  }
  return out;
}

function normalizeCode(raw: string): string {
  return raw.toUpperCase().replace(/[^0-9A-Z]/g, "");
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const upgrade = request.headers.get("Upgrade");

    // Health check.
    if (url.pathname === "/") {
      return new Response("minesweeper-relay ok", { status: 200 });
    }

    if (upgrade !== "websocket") {
      return new Response("Expected WebSocket Upgrade", { status: 426 });
    }

    // Host creates a room. The code is generated here; the DO id derives from it.
    if (url.pathname === "/create") {
      const code = randomCode();
      const id = env.ROOM.idFromName(code);
      const stub = env.ROOM.get(id);
      const inner = new URL(request.url);
      inner.pathname = `/host/${code}`;
      return stub.fetch(new Request(inner.toString(), request));
    }

    // Guest joins by code.
    const join = url.pathname.match(/^\/join\/([A-Za-z0-9]+)$/);
    if (join) {
      const code = normalizeCode(join[1]);
      if (code.length !== CODE_LEN) {
        return new Response("Bad room code", { status: 400 });
      }
      const id = env.ROOM.idFromName(code);
      const stub = env.ROOM.get(id);
      const inner = new URL(request.url);
      inner.pathname = `/guest/${code}`;
      return stub.fetch(new Request(inner.toString(), request));
    }

    // Host re-attaches to an existing room within its grace window using
    // the hostToken it received on /create. ?token=<hostToken> in the URL.
    const reclaim = url.pathname.match(/^\/reclaim\/([A-Za-z0-9]+)$/);
    if (reclaim) {
      const code = normalizeCode(reclaim[1]);
      if (code.length !== CODE_LEN) {
        return new Response("Bad room code", { status: 400 });
      }
      const id = env.ROOM.idFromName(code);
      const stub = env.ROOM.get(id);
      const inner = new URL(request.url);
      inner.pathname = `/reclaim-do/${code}`;
      // Preserve ?token=... so the DO can validate it.
      inner.search = url.search;
      return stub.fetch(new Request(inner.toString(), request));
    }

    return new Response("Not found", { status: 404 });
  },
};
