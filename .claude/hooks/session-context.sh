#!/usr/bin/env bash
# Re-inject critical stack patterns and git state after context compaction.
# Without this, Claude loses awareness of CF-specific rules in long sessions.

BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null)
if [[ -n "$BRANCH" ]]; then
	RECENT=$(git -C "$CLAUDE_PROJECT_DIR" log main..HEAD --oneline 2>/dev/null | head -8)
	UNCOMMITTED=$(git -C "$CLAUDE_PROJECT_DIR" diff --name-only HEAD 2>/dev/null)
	UNCOMMITTED_COUNT=$(echo "$UNCOMMITTED" | grep -c '.' 2>/dev/null || echo 0)
	[[ -z "$UNCOMMITTED" ]] && UNCOMMITTED_COUNT=0

	echo "### Git state at compaction"
	echo "Branch: $BRANCH"
	if [[ -n "$RECENT" ]]; then
		echo "Commits on this branch:"
		echo "$RECENT" | sed 's/^/  /'
	fi
	if [[ "$UNCOMMITTED_COUNT" -gt 0 ]]; then
		echo "Uncommitted ($UNCOMMITTED_COUNT files): $(echo "$UNCOMMITTED" | tr '\n' ' ' | sed 's/ $//')"
	fi
	echo ""
fi

cat <<'EOF'
## Stack — Critical Patterns Reminder

### TanStack Start on Cloudflare Workers
- `getRouter()` MUST return a NEW router instance per call (SSR isolation per request)
- Vite plugin order: tailwindcss → tsconfigPaths → cloudflare → tanstackStart → viteReact
- `compatibility_flags: ["nodejs_compat"]` is required in wrangler.jsonc
- Worker entry is `src/entry.server.ts` — exports default { fetch, scheduled? } + named Workflow classes
- Route loaders run on BOTH client and server — use createServerFn for env/D1/R2/AI access
- Never edit `routeTree.gen.ts` or `worker-configuration.d.ts` (generated)

### Server Functions (the API layer — no tRPC)
- `createServerFn({ method }).inputValidator(zodSchema).handler(async ({ data }) => ...)`
- Bindings: `import { env } from 'cloudflare:workers'` — never `process.env`
- Auth in server fns: pass `getRequestHeaders()` to `auth.api.getSession({ headers })`
- Consume from React: `useQuery({ queryKey, queryFn: () => fn({ data }) })`

### AI Gateway (mandatory routing)
- Workers AI: `env.AI.run(model, input, { gateway: { id: env.AI_GATEWAY_ID } })`
- AI SDK: configure provider `baseURL` to `https://gateway.ai.cloudflare.com/v1/<acct>/<gw>/<provider>`
- No direct provider URLs anywhere

### better-auth on D1
- `tanstackStartCookies()` MUST be the LAST plugin
- `(env as unknown as Record<string, string>).BETTER_AUTH_SECRET` for the secret
- `drizzleAdapter(db, { provider: 'sqlite', schema })`

### Drizzle on D1
- `createDb(d1: D1Database)` factory; never module-scoped
- SQLite types: text, integer (mode: 'boolean' | 'timestamp'), real, blob
- `bun db:generate` → `bun db:migrate:local` (never edit migrations/*.sql)

### Cloudflare Workflows / Cron
- Workflow class extends `WorkflowEntrypoint<Env, Params>`, exported by NAME from entry.server.ts
- Wrap retryable side effects in `step.do('name', { retries }, async () => ...)`
- Trigger: `env.MY_WORKFLOW.create({ id, params })` — IDs must be deterministic for idempotent triggers
- Cron: `scheduled(event, env)` dispatches by `event.cron` string match; keep it tiny, hand off to a Workflow

### Zod 4 (import from zod/v4)
- `.extend()` not `.merge()`
- `z.email()`, `z.uuid()` (top-level) not `z.string().email()`
- `z.treeifyError()` not `.format()` / `.flatten()`

### Code Style (Biome enforced)
- Named exports only (route files and config files exempted)
- `import type {}` for type-only imports
- `bun check:fix` runs automatically on edited files

### Wrangler Safety
- `wrangler d1 execute --remote` and `wrangler secret delete` are DENIED — confirm with user first
- After editing wrangler.jsonc: `bun cf-typegen` regenerates worker-configuration.d.ts
EOF

exit 0
