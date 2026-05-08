---
name: add-workflow
description: Add a Cloudflare Workflow class with binding and trigger pattern
user-invocable: true
argument-hint: workflow-name
---

Add a Workflow: **$ARGUMENTS**

Workflows are durable, retryable orchestrations on Cloudflare. Use them for any work that:
- Takes more than ~30 seconds
- Has multiple side effects with retry semantics
- Needs to sleep / wait
- Must survive Worker restarts

## Process

1. **Create the workflow class** at `src/server/workflows/<name>.workflow.ts`:

```ts
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from 'cloudflare:workers'

interface <Name>Params {
  // ... params your workflow needs (e.g., orgId, jobId)
}

export class <Name>Workflow extends WorkflowEntrypoint<Env, <Name>Params> {
  async run(event: WorkflowEvent<<Name>Params>, step: WorkflowStep) {
    const params = event.payload

    // Each step.do is a checkpoint. On failure inside the callback, CF
    // retries up to `retries` times before failing the step. Successful
    // step output is persisted; replays skip re-executing it.
    const data = await step.do('fetch-data', { retries: { limit: 3, delay: '5s' } }, async () => {
      // ... fetch from D1, external API, etc.
      return { /* serializable result */ }
    })

    // Sleep is durable — survives Worker restarts
    // await step.sleep('wait', '5 minutes')

    await step.do('process', async () => {
      const db = this.env.DB
      // ... write back to D1
    })
  }
}
```

2. **Export the class from `src/entry.server.ts`** as a NAMED export:

```ts
export { <Name>Workflow } from './server/workflows/<name>.workflow'
```

Wrangler scans `main` for named exports of subclasses of `WorkflowEntrypoint`. Without the named export the workflow is invisible to the deploy.

3. **Add the binding to `wrangler.jsonc`**:

```jsonc
"workflows": [
  {
    "name": "<kebab-name>",
    "binding": "<BINDING_NAME>",
    "class_name": "<Name>Workflow",
    "script_name": "<your-worker-name>"
  }
]
```

`script_name` must match `name` at the top of `wrangler.jsonc` (the worker name). Workflow names are global per CF account — if you have a staging deploy, suffix the name there.

4. **Regenerate types**:

```bash
bun cf-typegen
```

(`env.<BINDING_NAME>` now has type `Workflow`.)

5. **Trigger the workflow** from a server function:

```ts
import { createServerFn } from '@tanstack/react-start'
import { env } from 'cloudflare:workers'

export const start<Name> = createServerFn({ method: 'POST' })
  .handler(async () => {
    const id = `<name>-${Date.now()}`  // or a deterministic ID for idempotent triggers
    const instance = await env.<BINDING_NAME>.create({ id, params: { /* ... */ } })
    return { instanceId: instance.id }
  })
```

For idempotent triggers (cron, retried webhook), use a DETERMINISTIC ID like `<name>-<orgId>-<scheduledTime>` — Cloudflare rejects duplicate IDs by design, which IS the idempotency.

6. **Verify**:

```bash
bun typecheck
bun check:fix
```

7. **Inspect a running instance** (in another terminal):

```bash
wrangler workflows instances list <kebab-name>
wrangler workflows instances describe <kebab-name> <instance-id>
```

## Conventions

- One file per workflow. Filename: `<name>.workflow.ts`.
- Class extends `WorkflowEntrypoint<Env, Params>` from `cloudflare:workers` (NOT the npm package).
- Wrap retryable side effects in `step.do('name', { retries }, async () => ...)`. Pure deterministic computation can sit between steps.
- `step.do` callbacks must return SERIALIZABLE values (no functions, no Date — convert to ISO strings).
- Use `step.sleep('name', duration)` / `step.sleepUntil('name', date)` for waits — never `setTimeout`.
- Each step name must be unique within a single `run()`.
- Don't import worker bindings via `import { env }` inside the workflow — use `this.env`. The class receives `Env` as the first generic.
