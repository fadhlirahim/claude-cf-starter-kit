---
name: setup
description: Bootstrap a fresh Cloudflare Workers + TanStack Start project with a working AI-Gateway-routed Workers AI route, better-auth on D1, Drizzle, and shadcn — from zero
user-invocable: true
argument-hint: (none)
context: fork
agent: general-purpose
---

Bootstrap a Cloudflare-native fullstack TypeScript project from zero. The starter kit installed `CLAUDE.md`, `biome.json`, and `.claude/`; this skill creates the source tree wired to those conventions.

Run only when `src/` does not yet exist. If it does, **stop and ask** — the user probably wants `/add-route` or `/add-server-fn`.

## Preflight

1. Verify tools:
   - `bun --version` (>= 1.1)
   - `git --version`
   - The project root must be its own git repo (`git rev-parse --show-toplevel` equals the cwd). If not, `git init` first — `bun add` runs the `prepare` script (`lefthook install`), which otherwise installs hooks into whatever repo encloses the directory.
   - `wrangler whoami` — confirms a logged-in CF account. If not logged in, tell the user to run `wrangler login` and stop.
2. Ask the user:
   - **App name** (replaces `[App Name]` in `CLAUDE.md` and becomes the Worker name in `wrangler.jsonc`).
   - **Cloudflare account ID** — read from `wrangler whoami` output and confirm.
   - **AI Gateway slug** — if they don't have one, suggest they create it now via `wrangler ai gateway create <slug>` (or in the dashboard) and feed the slug back. AI Gateway must exist before the demo route works.
   - **D1 database name** — default to `<app-name>-db`. We'll create it in step 4.
   - **(Optional) R2 bucket name** — default to `<app-name>-assets`. Skip if user doesn't want R2 yet; the `/add-r2` skill can add it later.
3. Read `CLAUDE.md` once. Do not duplicate its rules here — follow them.

## Step 1 — `package.json` (already may exist from installer)

The starter-kit installer left a minimal `package.json`. If absent, create:

```json
{
  "name": "<app-name>",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite dev",
    "prepare": "lefthook install",
    "build": "vite build",
    "deploy": "vite build && wrangler deploy",
    "deploy:stg": "WRANGLER_ENV=stg vite build && wrangler deploy --env stg",
    "check": "bunx biome check .",
    "check:fix": "bunx biome check --write .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "cf-typegen": "wrangler types",
    "db:generate": "bunx drizzle-kit generate",
    "db:migrate:local": "wrangler d1 migrations apply DB --local",
    "db:migrate:remote": "wrangler d1 migrations apply DB --remote",
    "db:auth": "bunx @better-auth/cli@latest generate --config src/server/auth.cli.ts --output src/server/db/schema.ts"
  }
}
```

## Step 2 — Install dependencies

Two groups so failures are easy to diagnose:

```bash
# runtime
bun add \
  @tanstack/react-router @tanstack/react-router-devtools \
  @tanstack/react-router-ssr-query \
  @tanstack/react-start \
  @tanstack/react-query @tanstack/react-query-devtools \
  @tanstack/react-form @tanstack/zod-adapter \
  better-auth \
  drizzle-orm \
  zod \
  ai @ai-sdk/openai @ai-sdk/google \
  react react-dom \
  clsx tailwind-merge class-variance-authority lucide-react \
  sonner

# dev
bun add -d \
  typescript @types/react @types/react-dom @types/node \
  vite @vitejs/plugin-react-swc vite-tsconfig-paths \
  @cloudflare/vite-plugin \
  @tailwindcss/vite tailwindcss tw-animate-css \
  @biomejs/biome \
  drizzle-kit \
  vitest@^4.1 @cloudflare/vitest-plugin @testing-library/react @testing-library/jest-dom jsdom \
  wrangler \
  lefthook
```

After install, run `bun install` once to ensure lockfile.

## Step 3 — `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "lib": ["ESNext", "DOM", "DOM.Iterable"],
    "types": ["vite/client", "@cloudflare/vitest-plugin/types"],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src", "*.config.ts", "worker-configuration.d.ts"]
}
```

## Step 4 — Cloudflare resources (D1, AI Gateway, optional R2)

Create the D1 database via wrangler. Capture the `database_id` from the output:

```bash
wrangler d1 create <app-name>-db
# → outputs a UUID; copy it into wrangler.jsonc next step
```

If the user wanted R2:

```bash
wrangler r2 bucket create <app-name>-assets
```

If the user wanted an AI Gateway and hasn't made one yet, ask them to create it via the dashboard or:

```bash
wrangler ai gateway create <slug>
```

## Step 5 — `wrangler.jsonc`

```jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "<app-name>",
  "compatibility_date": "2026-09-20",
  "compatibility_flags": ["nodejs_compat"],
  "main": "src/entry.server.ts",
  "observability": {
    "enabled": true,
    "head_sampling_rate": 1
  },
  "vars": {
    "AI_GATEWAY_ID": "<gateway-slug>",
    // Public origin better-auth builds URLs from. .dev.vars overrides it locally.
    "BETTER_AUTH_URL": "https://<your-domain>"
  },
  "d1_databases": [
    {
      "binding": "DB",
      "database_name": "<app-name>-db",
      "database_id": "<paste-uuid-from-step-4>",
      "migrations_dir": "drizzle/migrations"
    }
  ],
  "ai": {
    "binding": "AI"
  }
  // Add as needed (see /add-r2, /add-workflow, /add-cron, /add-email):
  // "r2_buckets": [{ "bucket_name": "<bucket>", "binding": "ASSETS_BUCKET" }],
  // "send_email": [{ "name": "SEND_EMAIL" }],
  // "triggers": { "crons": ["0 * * * *"] },
  // "workflows": [{ "name": "...", "binding": "...", "class_name": "..." }]
}
```

## Step 6 — `.dev.vars` (CF local secrets)

`.dev.vars` is **blocked from writes** by `protect-sensitive.sh`. Tell the user to create it themselves:

```bash
cat > .dev.vars <<'EOF'
BETTER_AUTH_SECRET=<run: openssl rand -base64 32>
BETTER_AUTH_URL=http://localhost:5173
CLOUDFLARE_ACCOUNT_ID=<from wrangler whoami>
# Optional, only if you'll use AI SDK with OpenAI/Google through the gateway:
# OPENAI_API_KEY=
# GOOGLE_GENERATIVE_AI_API_KEY=
EOF
```

For prod, secrets are set with `wrangler secret put NAME` (or in the dashboard). Do not store secrets in `wrangler.jsonc` `vars` — vars are public at runtime.

## Step 7 — `vite.config.ts`

Plugin order matters: tailwindcss → tsconfigPaths → cloudflare → tanstackStart → viteReact.

```ts
import { cloudflare } from '@cloudflare/vite-plugin'
import tailwindcss from '@tailwindcss/vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import viteReact from '@vitejs/plugin-react-swc'
import { defineConfig } from 'vite'
import tsConfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  server: { port: 5173 },
  plugins: [
    tailwindcss(),
    tsConfigPaths({ projects: ['./tsconfig.json'] }),
    cloudflare({ viteEnvironment: { name: 'ssr' } }),
    tanstackStart(),
    viteReact(),
  ],
})
```

## Step 8 — `drizzle.config.ts`

```ts
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  dialect: 'sqlite',
  schema: './src/server/db/schema.ts',
  out: './drizzle/migrations',
})
```

## Step 9 — `components.json` (shadcn)

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "src/styles/app.css",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  },
  "iconLibrary": "lucide"
}
```

## Step 10 — `lefthook.yml`

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: biome
      glob: "*.{js,jsx,ts,tsx,json,jsonc,css}"
      run: bunx biome check --write --no-errors-on-unmatched {staged_files}
      stage_fixed: true

    - name: typecheck
      glob: "*.{ts,tsx}"
      run: bun run typecheck
```

Then run `bun run prepare` once to install the hooks.

## Step 11 — `vitest.config.ts`

Use the workers pool for tests that need bindings:

```ts
import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-plugin'
import { defineConfig } from 'vitest/config'

export default defineConfig(async () => {
  const migrations = await readD1Migrations('./drizzle/migrations')
  return {
    plugins: [
      cloudflareTest({
        // The real entry needs the Start Vite plugin's virtual modules.
        main: './src/test-utils/test-worker.ts',
        wrangler: { configPath: './wrangler.jsonc' },
        miniflare: {
          compatibilityFlags: ['nodejs_compat'],
          bindings: { TEST_MIGRATIONS: migrations },
        },
      }),
    ],
  }
})
```

- `vitest` is pinned to `^4.1` — the workers pool doesn't support vitest 5 yet.
- Tests run against a stub `main` (`src/test-utils/test-worker.ts`), so they exercise bindings and services, not the Start app. `src/entry.server.ts` imports `#tanstack-*` virtual modules that only exist under the Start plugin.
- The pool rejects `environment: 'jsdom'`, so component tests need a separate vitest project without `cloudflareTest()`.

## Step 12 — `bun cf-typegen`

Now that `wrangler.jsonc` is in place, generate `worker-configuration.d.ts`:

```bash
bun cf-typegen
```

This creates the typed `Env` interface. Future binding additions require re-running this.

## Step 13 — Source tree

Create directories:

```bash
mkdir -p src/{routes/_public,routes/_authed,routes/api/auth,server/db,server/ai,lib/validators,components/ui,hooks,styles,test-utils}
```

### `src/styles/app.css`

```css
@import 'tailwindcss';
@import 'tw-animate-css';

/* Minimal tokens so the demo builds; `bunx shadcn init` replaces them. */
@theme {
  --color-background: light-dark(#ffffff, #0a0a0a);
  --color-foreground: light-dark(#0a0a0a, #fafafa);
}

:root { color-scheme: light dark; }
body { @apply bg-background text-foreground antialiased; }
```

(Run `bunx shadcn init` after the dev server is up to populate the full shadcn palette. Tailwind v4 rejects `@apply` on undefined tokens, so the two above are required.)

### `src/server/db/schema.ts`

Don't hand-write the auth tables — `bun db:auth` generates them in Step 14 (columns, indexes, and `relations()` track better-auth's version). Start with a placeholder:

```ts
// Auth tables are generated by `bun db:auth`. Domain tables go below them.
export {}
```

### `src/server/db/index.ts`

```ts
import { drizzle } from 'drizzle-orm/d1'
import * as schema from './schema'

export function createDb(d1: D1Database) {
  return drizzle(d1, { schema })
}

export type Database = ReturnType<typeof createDb>
export type Tx = Parameters<Parameters<Database['transaction']>[0]>[0]
export type DbOrTx = Database | Tx
```

### `src/server/auth.options.ts`

Shared by `createAuth()` and the CLI config, so plugins live in one place. No `cloudflare:workers` import — the CLI runs in Node.

```ts
import type { BetterAuthOptions } from 'better-auth'
import { tanstackStartCookies } from 'better-auth/tanstack-start'

export const authOptions = {
  emailAndPassword: {
    enabled: true,
    minPasswordLength: 8,
  },
  plugins: [
    tanstackStartCookies(), // MUST be last
  ],
} satisfies BetterAuthOptions
```

### `src/server/auth.ts`

```ts
import { env } from 'cloudflare:workers'
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import { authOptions } from './auth.options'
import { createDb } from './db'
import * as schema from './db/schema'

export function createAuth(d1: D1Database) {
  const db = createDb(d1)
  const secret = (env as unknown as Record<string, string>).BETTER_AUTH_SECRET || undefined

  return betterAuth({
    ...authOptions,
    secret,
    // Pass explicitly: better-auth would otherwise read process.env, which this stack doesn't use.
    baseURL: env.BETTER_AUTH_URL,
    database: drizzleAdapter(db, { provider: 'sqlite', schema }),
  })
}

export type Auth = ReturnType<typeof createAuth>
```

### `src/server/auth.cli.ts`

The better-auth CLI needs a module-level `auth` instance; the app only has a per-request factory. This file exists solely for `bun db:auth` — never import it from app code.

```ts
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import { drizzle } from 'drizzle-orm/d1'
import { authOptions } from './auth.options'

// The CLI only reads the adapter's shape; the D1 handle is never queried.
export const auth = betterAuth({
  ...authOptions,
  database: drizzleAdapter(drizzle({} as D1Database), { provider: 'sqlite' }),
})
```

### `src/server/auth.functions.ts`

```ts
import { createServerFn } from '@tanstack/react-start'
import { getRequestHeaders } from '@tanstack/react-start/server'
import { env } from 'cloudflare:workers'
import { createAuth } from './auth'

export const getSession = createServerFn({ method: 'GET' }).handler(async () => {
  const auth = createAuth(env.DB)
  const headers = getRequestHeaders()
  return auth.api.getSession({ headers })
})
```

### `src/lib/auth-client.ts`

```ts
import { createAuthClient } from 'better-auth/react'
import { inferAdditionalFields } from 'better-auth/client/plugins'
import type { Auth } from '@/server/auth'

export const authClient = createAuthClient({
  plugins: [inferAdditionalFields<Auth>()],
})

export const { signIn, signUp, signOut, useSession } = authClient
```

### `src/routes/api/auth/$.ts`

```ts
import { createFileRoute } from '@tanstack/react-router'
import { env } from 'cloudflare:workers'
import { createAuth } from '@/server/auth'

export const Route = createFileRoute('/api/auth/$')({
  server: {
    handlers: {
      GET: ({ request }) => createAuth(env.DB).handler(request),
      POST: ({ request }) => createAuth(env.DB).handler(request),
    },
  },
})
```

### `src/server/ai/chat.functions.ts` — the headline AI Worker route

```ts
import { createServerFn } from '@tanstack/react-start'
import { env } from 'cloudflare:workers'
import { z } from 'zod/v4'

const Input = z.object({
  prompt: z.string().min(1).max(2000),
})

export const chat = createServerFn({ method: 'POST' })
  .validator(Input)
  .handler(async ({ data }) => {
    // Workers AI binding, routed through AI Gateway for caching/observability.
    const response = await env.AI.run(
      '@cf/meta/llama-3.1-8b-instruct',
      { messages: [{ role: 'user', content: data.prompt }] },
      { gateway: { id: env.AI_GATEWAY_ID } },
    )
    return { reply: typeof response.response === 'string' ? response.response : '' }
  })
```

### `src/router.tsx`

```tsx
import { QueryClient } from '@tanstack/react-query'
import { createRouter } from '@tanstack/react-router'
import { setupRouterSsrQueryIntegration } from '@tanstack/react-router-ssr-query'
import { routeTree } from './routeTree.gen'

export function getRouter() {
  // New QueryClient per call. getRouter() runs once per request on the server
  // and once on the client, so this is already per-request-safe — a module-level
  // singleton would leak one user's cache into another's SSR.
  const queryClient = new QueryClient({
    defaultOptions: { queries: { staleTime: 60 * 1000 } },
  })

  const router = createRouter({
    routeTree,
    defaultPreload: 'intent',
    defaultPreloadStaleTime: 0, // Query owns caching/staleness, not the router
    scrollRestoration: true,
    context: { queryClient },
  })

  // Wires dehydrate -> stream -> hydrate of the Query cache across the SSR
  // boundary, plus redirect() handling and the QueryClientProvider wrap.
  // WITHOUT this, loader `ensureQueryData` prefetches never reach the client
  // and every server-fetched query refetches on hydration (silent double fetch).
  setupRouterSsrQueryIntegration({ router, queryClient })

  return router
}

declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof getRouter>
  }
}
```

> Requires `@tanstack/react-router-ssr-query`. The manual `Wrap` + `QueryClientProvider`
> pattern makes Query *run* but does NOT serialize the server cache into the HTML —
> use the integration helper so SSR data loading actually works end to end.

### `src/routes/__root.tsx`

```tsx
import type { QueryClient } from '@tanstack/react-query'
import { HeadContent, Outlet, Scripts, createRootRouteWithContext } from '@tanstack/react-router'
import '@/styles/app.css'

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: '<App Name>' },
    ],
  }),
  component: RootComponent,
})

function RootComponent() {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        <Outlet />
        <Scripts />
      </body>
    </html>
  )
}
```

### `src/routes/index.tsx` — demo page that calls the AI route

```tsx
import { useMutation } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { chat } from '@/server/ai/chat.functions'

export const Route = createFileRoute('/')({
  component: HomePage,
})

function HomePage() {
  const [prompt, setPrompt] = useState('')
  const ask = useMutation({ mutationFn: (p: string) => chat({ data: { prompt: p } }) })

  return (
    <main className="mx-auto max-w-2xl space-y-4 p-8">
      <h1 className="font-semibold text-2xl">AI on Cloudflare Workers</h1>
      <textarea
        className="w-full rounded border p-2"
        rows={4}
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        placeholder="Ask anything..."
      />
      <button
        type="button"
        className="rounded bg-foreground px-4 py-2 text-background disabled:opacity-50"
        onClick={() => ask.mutate(prompt)}
        disabled={!prompt || ask.isPending}
      >
        {ask.isPending ? 'Thinking…' : 'Send'}
      </button>
      {ask.error && <p className="text-red-600">{ask.error.message}</p>}
      {ask.data && <pre className="whitespace-pre-wrap rounded border p-3">{ask.data.reply}</pre>}
    </main>
  )
}
```

### `src/entry.server.ts`

```ts
import handler from '@tanstack/react-start/server-entry'

export default {
  fetch: (request) => handler.fetch(request),
} satisfies ExportedHandler<Env>
```

A plain `ExportedHandler` (not Start's `createServerEntry`, which only types `fetch`) so `/add-cron` can add `scheduled` and `/add-workflow` / `/add-realtime` can add named class exports alongside it.

### `src/lib/utils.ts`

```ts
import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

### `src/test-utils/test-worker.ts`

```ts
// Test-only Worker entry: the real one needs the Start Vite plugin's virtual modules.
export default {
  fetch: () => new Response('ok'),
}
```

### `src/test-utils/env.d.ts`

```ts
// Test-only bindings injected by vitest.config.ts.
declare namespace Cloudflare {
  interface Env {
    TEST_MIGRATIONS: D1Migration[]
  }
}
```

### `src/server/db/schema.test.ts` — smoke test for the pool + migrations

```ts
import { applyD1Migrations } from 'cloudflare:test'
import { env } from 'cloudflare:workers'
import { beforeAll, describe, expect, it } from 'vitest'

describe('D1 schema', () => {
  beforeAll(async () => {
    await applyD1Migrations(env.DB, env.TEST_MIGRATIONS)
  })

  it('has the auth tables', async () => {
    const { results } = await env.DB.prepare(
      "select name from sqlite_master where type = 'table' and name = 'user'",
    ).all()
    expect(results).toHaveLength(1)
  })
})
```

### `src/test-utils/cloudflare-workers-stub.ts`

```ts
// Used by vitest in non-pool tests to satisfy `import { env } from 'cloudflare:workers'`.
export const env = {} as unknown as Env
```

## Step 14 — Apply auth schema and migrations

Now run, in order:

```bash
bun db:auth          # generates the auth tables into schema.ts (answer y to overwrite)
bun db:generate      # writes drizzle/migrations/0000_*.sql
bun db:migrate:local # applies to local D1 (Miniflare)
```

`bun db:auth` overwrites `schema.ts` — on later runs, re-add domain tables underneath the auth block.

## Step 15 — Verify

Run in order; stop at the first failure:

```bash
bun cf-typegen       # one more pass after all bindings are in place
bun run build        # also generates routeTree.gen.ts, which typecheck needs
bun typecheck        # zero errors
bun check:fix        # Biome
bun run test         # D1 schema smoke test via the workers pool
bun dev              # boots on http://localhost:5173
```

Then in the browser:

- `/` renders the demo page.
- Type a prompt and click Send → response appears (AI Gateway logs the call in the CF dashboard). An error like `2001: Please configure AI Gateway` means the slug in `AI_GATEWAY_ID` doesn't exist yet.
- Always run `bun run build` before claiming success: in dev, TanStack's import protection *mocks* a bad client→server import instead of failing, so the demo can look fine while being broken.

Open the AI Gateway dashboard and confirm the request appears in **Logs**. That's the smoke test that AI Gateway routing actually worked — without it you might be calling Workers AI directly, which still functions but bypasses the gateway.

## Step 16 — Hand-off

Tell the user, concisely:

- What was created (file count; don't enumerate).
- That `.dev.vars` was not written; they must create it before `bun dev` works (step 6 has the template).
- AI Gateway is wired — point them at the dashboard URL `https://dash.cloudflare.com/<account>/ai/ai-gateway`.
- Next steps:
  - `/add-server-fn <name>` for a new API endpoint.
  - `/add-d1-table <name>` for a new table.
  - `/add-r2`, `/add-workflow`, `/add-cron`, `/add-email`, `/add-ai-route` for each CF primitive.
  - `/deploy` to ship to prod (will set up `wrangler secret put BETTER_AUTH_SECRET` first).

## Guardrails

- **Don't** write `.dev.vars`, `drizzle/migrations/*.sql`, `routeTree.gen.ts`, or `worker-configuration.d.ts` — hooks block them by design.
- **Don't** add libraries not in `CLAUDE.md`'s stack table without asking. The kit is opinionated.
- **Don't** put secrets (API keys, BETTER_AUTH_SECRET) in `wrangler.jsonc` `vars`. Vars are PUBLIC at runtime.
- **Don't** use `process.env` in worker code — `import { env } from 'cloudflare:workers'`.
- **Don't** skip `bun cf-typegen` — type errors in `Env` will mask real bugs later.
- **Don't** claim success on `bun typecheck` alone — the AI Gateway log entry is the real smoke test.
- If a step fails (network, auth, version conflict), surface the error and stop. No silent `try/catch`, no fallbacks.
