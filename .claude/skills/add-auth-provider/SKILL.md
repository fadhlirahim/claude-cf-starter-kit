---
name: add-auth-provider
description: Wire a better-auth social provider (GitHub, Google, etc.) into the existing auth setup
user-invocable: true
argument-hint: provider-name (github|google|discord|...)
---

Add a social auth provider: **$ARGUMENTS**

## Process

1. **Register the OAuth app** in the provider's developer console (GitHub Settings → Developer settings → OAuth Apps, etc.). Capture the client ID and secret. Set the redirect/callback URL to:
   - Local dev: `http://localhost:5173/api/auth/callback/<provider>`
   - Prod: `https://<your-domain>/api/auth/callback/<provider>`

2. **Add public env vars** to `wrangler.jsonc` `vars` if any are non-secret. Most providers expect both client ID (sometimes ok to expose) and client SECRET (must be a CF secret).

3. **Set the secrets** for prod:

```bash
wrangler secret put <PROVIDER>_CLIENT_ID
wrangler secret put <PROVIDER>_CLIENT_SECRET
```

For local dev, append to `.dev.vars` (the user must edit — `.dev.vars` is blocked from automated writes):

```
GITHUB_CLIENT_ID=...
GITHUB_CLIENT_SECRET=...
```

4. **Edit `src/server/auth.ts`** — add to `socialProviders` (see better-auth docs):

```ts
import { env } from 'cloudflare:workers'
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import { tanstackStartCookies } from 'better-auth/tanstack-start'
import { createDb } from './db'
import * as schema from './db/schema'

export function createAuth(d1: D1Database) {
  const db = createDb(d1)
  const e = env as unknown as Record<string, string>

  return betterAuth({
    secret: e.BETTER_AUTH_SECRET,
    database: drizzleAdapter(db, { provider: 'sqlite', schema }),
    emailAndPassword: { enabled: true, minPasswordLength: 8 },
    socialProviders: {
      <provider>: {
        clientId: e.<PROVIDER>_CLIENT_ID,
        clientSecret: e.<PROVIDER>_CLIENT_SECRET,
      },
    },
    plugins: [
      tanstackStartCookies(), // MUST be last
    ],
  })
}

export type Auth = ReturnType<typeof createAuth>
```

5. **Trigger sign-in from the client**:

```tsx
import { signIn } from '@/lib/auth-client'

<button type="button" onClick={() => signIn.social({ provider: '<provider>' })}>
  Sign in with <Provider>
</button>
```

6. **Verify**:

```bash
bun typecheck
bun check:fix
bun dev
```

Then click the button — the OAuth dance should land you back logged in.

## Conventions

- Always use `wrangler secret put` for client SECRET. Putting a secret in `wrangler.jsonc` `vars` exposes it at runtime.
- `auth.api.getSession({ headers: getRequestHeaders() })` — same as email/password. Provider doesn't change this.
- Provider account links sit in the `account` table (one row per provider per user). better-auth handles the link/unlink flow.
- For local dev, the redirect URL must EXACTLY match what's registered. `localhost:5173` not `127.0.0.1:5173`.
- After adding a provider that introduces additional fields on `user`, run `bun db:auth && bun db:generate && bun db:migrate:local`.
