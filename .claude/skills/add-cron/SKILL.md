---
name: add-cron
description: Add a Cloudflare cron trigger and a scheduled handler dispatch case
user-invocable: true
argument-hint: "cron-expression handler-name"
---

Add a cron trigger: **$ARGUMENTS**

Cloudflare runs `scheduled(event, env, ctx)` on the cron schedule(s) you list in `wrangler.jsonc`. Multiple cron expressions share one handler — dispatch on `event.cron`.

## Process

1. **Add the expression to `wrangler.jsonc`**:

```jsonc
"triggers": {
  "crons": [
    "0 * * * *",      // hourly
    "0 */4 * * *",    // every 4 hours
    "15 3 * * *"      // daily at 03:15 UTC
  ]
}
```

Multiple expressions are fine. They all hit the same `scheduled` handler — you dispatch by string match.

2. **Add the handler** in `src/entry.server.ts`:

```ts
import { createStartHandler, defaultStreamHandler } from '@tanstack/react-start/server'

const fetch = createStartHandler(defaultStreamHandler)

const CRON_HOURLY = '0 * * * *'
const CRON_NIGHTLY = '15 3 * * *'

export default {
  fetch,
  async scheduled(event: ScheduledEvent, env: Env) {
    if (event.cron === CRON_HOURLY) {
      await runHourlyJob(env)
      return
    }
    if (event.cron === CRON_NIGHTLY) {
      await runNightlyJob(env)
      return
    }
    // Fallthrough: dispatch a Workflow per row
    // const orgs = await env.DB.prepare('SELECT id FROM org WHERE enabled = 1').all<{ id: string }>()
    // for (const org of orgs.results ?? []) {
    //   await env.MY_WORKFLOW.create({
    //     id: `cron-${org.id}-${event.scheduledTime}`,
    //     params: { orgId: org.id },
    //   })
    // }
  },
}

async function runHourlyJob(env: Env): Promise<void> {
  // Keep this small. Heavy work belongs in a Workflow.
  // ...
}

async function runNightlyJob(env: Env): Promise<void> {
  // ...
}

// Don't forget to re-export Workflow classes here too:
// export { MyWorkflow } from './server/workflows/my-workflow.workflow'
```

3. **(Recommended) Push heavy work into a Workflow** — see `/add-workflow`. The cron handler should be < 100ms wall time: query D1 for what to do, then trigger Workflows. The Workflow does the actual work with retry semantics.

4. **Test locally**:

```bash
wrangler dev --test-scheduled
```

In a second terminal:

```bash
curl "http://localhost:8787/__scheduled?cron=0+*+*+*+*"
```

(URL-encode the cron expression — spaces become `+`.) The dev process logs the dispatch.

5. **Verify**:

```bash
bun cf-typegen
bun typecheck
bun check:fix
```

## Conventions

- Cron expressions use UTC. Make this explicit in comments next to the trigger (e.g., `// 03:15 UTC`).
- The `scheduled` handler MUST be `async (event, env, ctx) => ...` and live alongside `fetch` in the default export of `src/entry.server.ts`. Wrangler picks it up by shape.
- Use `event.scheduledTime` (number, ms epoch) as the deterministic part of any Workflow ID you create — `cron-<id>-${event.scheduledTime}` is idempotent under retries.
- Don't await long work directly in `scheduled` — Cloudflare has a 30s default scheduled limit (configurable up to 15 minutes). Workflows scale beyond that.
- Don't read external secrets from `process.env` — use `env`. Crons run on the same Worker as fetch and have the same bindings.
