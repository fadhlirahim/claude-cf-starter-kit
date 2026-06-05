---
name: add-realtime
description: Add realtime synced state (useSyncedState) backed by a Durable Object over WebSockets
user-invocable: true
argument-hint: [room-namespace]
---

Add realtime synced state: **$ARGUMENTS**

A drop-in `useState` replacement that syncs a value across every client connected to the same room. State lives in a Durable Object, persists in DO storage, and is broadcast over WebSockets. Ported from RedwoodSDK's `useSyncedState` — without the RSC plumbing, since this stack is server-fn-first.

**Semantics — read before using:**
- **Last-write-wins, server-authoritative.** A Durable Object is single-threaded, so the DO *is* the serialization point: the last update to arrive wins, with a total order, for free. No vector clocks, no seq numbers.
- **NOT a CRDT.** Good for presence, cursors, shared toggles, live counters, simple shared forms. Do NOT use for collaborative text editing — that needs OT/CRDT and is out of scope.
- This is the legitimate `useEffect` exception. CLAUDE.md bans `useEffect` for *data fetching*; a WebSocket subscription is a subscription, not fetching.

## Process

1. **Create the Durable Object** at `src/server/realtime/sync-room.do.ts`:

```ts
import { DurableObject } from 'cloudflare:workers'

type Snapshot = { type: 'snapshot'; state: Record<string, unknown> }
type Update = { type: 'update'; key: string; value: unknown }

export class SyncRoom extends DurableObject<Env> {
  async fetch(_request: Request): Promise<Response> {
    const { 0: client, 1: server } = new WebSocketPair()

    // Hibernation API: the DO evicts from memory between messages while the
    // socket stays open. NON-NEGOTIABLE — `server.accept()` instead would keep
    // the DO billed in memory for the whole connection. Idle tabs become a cost bomb.
    this.ctx.acceptWebSocket(server)

    // Send the current state to the freshly connected client.
    const entries = await this.ctx.storage.list<unknown>()
    const snapshot: Snapshot = { type: 'snapshot', state: Object.fromEntries(entries) }
    server.send(JSON.stringify(snapshot))

    return new Response(null, { status: 101, webSocket: client })
  }

  // Hibernation handlers are methods on the class (NOT closures on the socket).
  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    const msg = JSON.parse(typeof message === 'string' ? message : '') as Update
    if (msg.type !== 'update') return

    await this.ctx.storage.put(msg.key, msg.value)

    // Broadcast to every peer except the sender (it already applied optimistically).
    const payload = JSON.stringify(msg)
    for (const peer of this.ctx.getWebSockets()) {
      if (peer !== ws) peer.send(payload)
    }
  }

  async webSocketClose(ws: WebSocket, code: number, _reason: string, _wasClean: boolean) {
    ws.close(code)
  }
}
```

2. **Export the class from `src/entry.server.ts`** as a NAMED export (Wrangler scans `main` for it, same as Workflows):

```ts
export { SyncRoom } from './server/realtime/sync-room.do'
```

3. **Handle the WebSocket upgrade in `src/entry.server.ts`** — BEFORE the TanStack Start handler. A WS upgrade returns a `101` with a `webSocket` field; it cannot be a server function (those are GET/POST RPC). Intercept in the Worker `fetch`:

```ts
import { createAuth } from './server/auth'

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    const url = new URL(request.url)

    if (url.pathname === '/api/realtime' && request.headers.get('upgrade') === 'websocket') {
      // Auth at the upgrade — without it anyone can join any room.
      const session = await createAuth(env.DB).api.getSession({ headers: request.headers })
      if (!session) return new Response('unauthorized', { status: 401 })

      const room = url.searchParams.get('room')
      if (!room) return new Response('missing room', { status: 400 })

      // Namespace the room so tenants can't collide: `<orgId>:<room>`.
      const id = env.SYNC_ROOM.idFromName(`${session.user.id}:${room}`)
      return env.SYNC_ROOM.get(id).fetch(request)
    }

    return handler.fetch(request, env, ctx) // existing TanStack Start handler
  },
}
```

> Adjust the namespace key to your tenancy model (e.g. `orgId` instead of `user.id` for shared rooms). Keep the auth check — it's the only thing standing between a user and another tenant's room.

4. **Add the binding + migration to `wrangler.jsonc`**:

```jsonc
"durable_objects": {
  "bindings": [{ "name": "SYNC_ROOM", "class_name": "SyncRoom" }]
},
"migrations": [
  { "tag": "v1", "new_sqlite_classes": ["SyncRoom"] }
]
```

Use `new_sqlite_classes` (SQLite-backed storage, the modern default), NOT `new_classes`. If a `migrations` array already exists, append a new tag — never rewrite an applied tag.

5. **Regenerate types**:

```bash
bun cf-typegen
```

(`env.SYNC_ROOM` now has type `DurableObjectNamespace<SyncRoom>`.)

6. **Create the client hook** at `src/hooks/use-synced-state.ts`:

```ts
import { useCallback, useEffect, useRef, useState } from 'react'

type Inbound =
  | { type: 'snapshot'; state: Record<string, unknown> }
  | { type: 'update'; key: string; value: unknown }

export function useSyncedState<T>(room: string, key: string, initial: T) {
  const [value, setValue] = useState<T>(initial)
  const wsRef = useRef<WebSocket | null>(null)

  useEffect(() => {
    // SSR no-op: connect only on the client, after hydration.
    if (typeof window === 'undefined') return

    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const ws = new WebSocket(`${proto}://${location.host}/api/realtime?room=${encodeURIComponent(room)}`)
    wsRef.current = ws

    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data) as Inbound
      if (msg.type === 'snapshot') {
        if (key in msg.state) setValue(msg.state[key] as T)
      } else if (msg.type === 'update' && msg.key === key) {
        setValue(msg.value as T)
      }
    }

    return () => ws.close()
  }, [room, key])

  const set = useCallback(
    (next: T) => {
      setValue(next) // optimistic local apply
      wsRef.current?.send(JSON.stringify({ type: 'update', key, value: next }))
    },
    [key],
  )

  return [value, set] as const
}
```

7. **Use it** — identical shape to `useState`:

```tsx
function LiveToggle({ room }: { room: string }) {
  const [on, setOn] = useSyncedState(room, 'enabled', false)
  return <button onClick={() => setOn(!on)}>{on ? 'On' : 'Off'}</button>
}
```

8. **Verify**:

```bash
bun typecheck
bun check:fix
```

Test realtime with two browser tabs pointed at the same room — toggling in one should reflect in the other.

## Conventions

- DO class extends `DurableObject<Env>` from `cloudflare:workers`. One realtime DO is enough — rooms are partitioned by `idFromName`, not by class.
- ALWAYS use the Hibernation API (`ctx.acceptWebSocket` + `webSocketMessage`/`webSocketClose` methods). Never `server.accept()` — it keeps the DO resident and billed.
- Persist with `ctx.storage` (SQLite-backed). Values must be structured-clone serializable — no functions, no `Date` (use ISO strings).
- Auth at the upgrade, every time. Namespace room IDs by tenant so `idFromName` can't collide across orgs.
- The hook returns `[value, setter]` — keep it a drop-in for `useState` so call sites don't learn a new API.

## Known limitations (v1)

- **No reconnect/backoff.** A dropped socket stays dropped until remount. Production realtime wants exponential-backoff reconnection + a re-sync of the snapshot on reconnect — add it when you ship this for real.
- **No presence.** This syncs values, not "who's online." Presence (cursors, online status) is a separate concern on the same `SyncRoom` — add a `usePresence` hook later if needed.
- **No per-key access control.** Any room member can write any key. Add server-side validation in `webSocketMessage` if rooms are shared across trust boundaries.
