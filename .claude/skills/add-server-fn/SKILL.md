---
name: add-server-fn
description: Add a Zod-validated TanStack Start server function (the API layer)
user-invocable: true
argument-hint: function-name [GET|POST]
---

Add a server function: **$ARGUMENTS**

Server functions are the API layer in this stack — there is no tRPC. Each function is a typed RPC that runs on the Worker.

## Process

1. **Decide location**:
   - Domain logic: `src/server/<domain>/<name>.server.ts`
   - Co-located with a route: `src/routes/<route>.<name>.server.ts` is fine for narrow use
2. **Pick the method**:
   - `GET` for reads — cacheable, idempotent
   - `POST` for mutations — defaults; use this when in doubt
3. **Decide auth**:
   - Public: no middleware
   - Protected: gate on `auth.api.getSession({ headers: getRequestHeaders() })`
4. **Write the function**:

```ts
// src/server/<domain>/<name>.server.ts
import { createServerFn } from '@tanstack/react-start'
import { getRequestHeaders } from '@tanstack/react-start/server'
import { env } from 'cloudflare:workers'
import { z } from 'zod/v4'
import { createAuth } from '@/server/auth'
import { createDb } from '@/server/db'

const Input = z.object({
  // ... your fields, using top-level Zod 4 validators (z.email, z.uuid, etc.)
})

export const <name> = createServerFn({ method: 'POST' })
  .inputValidator(Input)
  .handler(async ({ data }) => {
    // For protected: uncomment
    // const auth = createAuth(env.DB)
    // const session = await auth.api.getSession({ headers: getRequestHeaders() })
    // if (!session) throw new Error('UNAUTHORIZED')

    const db = createDb(env.DB)
    // ... your logic
    return { /* result */ }
  })
```

5. **Consume from the client**:

```tsx
// src/routes/<page>.tsx
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { <name> } from '@/server/<domain>/<name>.server'

// Read
const { data } = useQuery({
  queryKey: ['<name>', id],
  queryFn: () => <name>({ data: { id } }),
})

// Mutation with invalidation
const queryClient = useQueryClient()
const m = useMutation({
  mutationFn: (input: Input) => <name>({ data: input }),
  onSuccess: () => queryClient.invalidateQueries({ queryKey: ['<name>'] }),
})
```

6. **Verify**:

```bash
bun typecheck
bun check:fix
```

## Conventions

- `Input` schema lives next to the function. Reusable validators go in `src/lib/validators/`.
- Throw `Error` for failures — TanStack Start serializes them. For typed expected failures, return a discriminated union.
- Import bindings via `import { env } from 'cloudflare:workers'` — never `process.env`.
- Keep handlers small. Extract logic into pure helpers under `src/server/<domain>/` that take the binding as an argument.
- For protected functions, consider a shared middleware once you have 2+ — see `/add-feature` for the pattern.
