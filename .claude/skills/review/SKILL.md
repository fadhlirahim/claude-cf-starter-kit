---
name: review
description: Review code changes for quality, security, and adherence to CLAUDE.md conventions on the CF + Start stack
user-invocable: true
context: fork
agent: general-purpose
---

Review the code changes in this project for quality, correctness, and adherence to CLAUDE.md conventions on the Cloudflare + TanStack Start + better-auth + Drizzle/D1 + Zod 4 stack.

## Review Checklist

1. **Type Safety**: No `any`. Proper Zod 4 validation (`zod/v4` import). Server functions use `.inputValidator(...)`.
2. **Auth Security**: Protected routes use `_authed` layout `beforeLoad`. Server functions either gate on session or are explicitly public. `auth.api.getSession({ headers: getRequestHeaders() })` (without `headers`, session is anonymous).
3. **Cloudflare Bindings**: Bindings accessed via `import { env } from 'cloudflare:workers'`. No `process.env` in worker code. No module-scoped binding access.
4. **AI Gateway**: All AI calls route through the gateway — `env.AI.run(model, input, { gateway: { id: env.AI_GATEWAY_ID } })` for Workers AI; `baseURL` configured for AI SDK clients. No direct provider URLs.
5. **Secrets**: No secrets in `wrangler.jsonc` `vars`. Secrets via `wrangler secret put` or `.dev.vars`.
6. **Server/Client Boundary**: `cloudflare:workers` imports stay in server-only files. Routes/components don't import worker bindings.
7. **Data Fetching**: TanStack Query consuming server functions. No `useEffect` for data. `useSuspenseQuery` for SSR (plain `useQuery` does NOT participate).
8. **Workflows**: Steps wrapped in `step.do(...)`. Deterministic IDs for idempotent triggers. Class exported by name from `entry.server.ts`.
9. **Cron**: Handler dispatches by `event.cron`. Heavy work delegated to a Workflow, not done inline.
10. **Email**: Goes through `createEmail({...}).send(...)` — never `env.SEND_EMAIL.send` directly.
11. **R2**: Binding access (`env.MY_BUCKET.put/get`), not the S3 API. Public reads via signed URLs.
12. **Drizzle**: `createDb(d1)` per-request. Relational queries (`db.query.<table>`). No hand-written SQL with template literals.
13. **Zod 4**: `.extend()` not `.merge()`. `z.email()` / `z.uuid()`. `z.treeifyError()`.
14. **better-auth**: `tanstackStartCookies()` LAST in plugins. `(env as ...).BETTER_AUTH_SECRET` for the secret.
15. **Conventions**: Named exports outside route/config files. Biome compliance. Files kebab-case.

## Instructions

- Run `git diff HEAD` (or read the files specified: $ARGUMENTS)
- For each issue found, cite `file:line` and explain why it's a problem
- Categorize as: CRITICAL | IMPORTANT | SUGGESTION
- End with a summary verdict: APPROVE / REQUEST CHANGES / DISCUSS
