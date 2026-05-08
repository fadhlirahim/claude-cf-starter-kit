---
name: debug
description: Debug issues systematically by tracing data flow through the CF + Start stack
user-invocable: true
argument-hint: description of the issue
---

Debug the specified issue: $ARGUMENTS

## Process

1. **Reproduce**: Understand the symptoms. Check `wrangler tail` (live worker logs), browser console, terminal output.
2. **Isolate**: Narrow to the file/function. Use `git diff` to check recent changes.
3. **Trace the data flow**:
   - Frontend: Component → `useQuery`/`useMutation` → server function → network → Worker
   - Backend (server fn): handler → `createDb(env.DB)` → Drizzle query → D1
   - Auth: `auth.api.getSession({ headers: getRequestHeaders() })` → middleware → handler
   - AI: `env.AI.run(..., { gateway: { id } })` → AI Gateway → model. Confirm the gateway logs show the call (CF dashboard → AI → AI Gateway → Logs).
   - Workflow: trigger → `env.MY_WORKFLOW.create({ id, params })` → instance → `step.do(...)` checkpoints
   - Cron: `scheduled(event, env)` → `event.cron` match → handler / Workflow dispatch
4. **Check common causes**:
   - **Binding access wrong**: `process.env.X` instead of `env.X` (returns undefined silently)
   - **Stale types**: Forgot `bun cf-typegen` after `wrangler.jsonc` change
   - **Module-scoped binding**: `const db = drizzle(env.DB)` at module top — fails outside request scope
   - **Auth shows anonymous**: missing `getRequestHeaders()` argument to `auth.api.getSession`
   - **`tanstackStartCookies()` not last**: cookies don't get written
   - **Wrong Zod import**: bare `zod` instead of `zod/v4`
   - **`.merge()` instead of `.extend()`** (Zod 4 removed merge)
   - **AI bypasses gateway**: direct provider URL in code; gateway dashboard shows no logs
   - **Workflow non-deterministic ID** under retried trigger → "instance already exists" rejection (this is the desired behavior)
   - **Missing query invalidation** after mutation
   - **Stale TanStack Query cache** — bump `queryKey` or invalidate
   - **`useQuery` expecting SSR** — only `useSuspenseQuery` and loader prefetches participate
   - **D1 transaction expectations** — D1 batches; not Postgres-level isolation
   - **`compatibility_flags: ["nodejs_compat"]` missing** in wrangler.jsonc → drizzle/better-auth fail at deploy
   - **Vite plugin order wrong** — `cloudflare()` must come before `tanstackStart()`, `viteReact()` last
5. **Fix**: Apply minimal fix. Don't refactor surrounding code.
6. **Verify**:

```bash
bun typecheck
bun test       # if relevant
bun dev        # confirm in the browser
```

If the issue surfaced in prod and not local, suspect environment differences (missing prod secret, `vars` mismatch, missing `wrangler secret put`, AI Gateway slug mismatch).
