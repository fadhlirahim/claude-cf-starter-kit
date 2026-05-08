---
name: scaffold
description: Scaffold a complete fullstack feature — D1 table, validators, server functions, route, and components
user-invocable: true
argument-hint: feature-name
---

Scaffold a fullstack feature: **$ARGUMENTS**

Use the `fullstack-builder` agent for this skill — it owns the build order.

## Files to Create (in order)

### 1. Drizzle schema — extend `src/server/db/schema.ts`

Add a table named after the feature (lower-case singular). Include `id`, `createdAt`, `updatedAt`. Define `relations()` if related to `user` or other domain tables.

Then run:

```bash
bun db:generate && bun db:migrate:local
```

### 2. Validators — `src/lib/validators/<feature>.ts`

```ts
import { z } from 'zod/v4'

export const <Feature>Schema = z.object({
  id: z.uuid(),
  // ... mirror schema.ts shape
  createdAt: z.date(),
  updatedAt: z.date(),
})

export const Create<Feature>Schema = <Feature>Schema.omit({ id: true, createdAt: true, updatedAt: true })
export const Update<Feature>Schema = <Feature>Schema.partial().extend({ id: z.uuid() })

export type <Feature> = z.output<typeof <Feature>Schema>
```

### 3. Server functions — `src/server/<feature>/<feature>.server.ts`

Implement CRUD as separate exported server functions. Auth via shared middleware once you have 2+ that need it.

```ts
import { createServerFn } from '@tanstack/react-start'
import { getRequestHeaders } from '@tanstack/react-start/server'
import { env } from 'cloudflare:workers'
import { z } from 'zod/v4'
import { createAuth } from '@/server/auth'
import { createDb } from '@/server/db'
import { Create<Feature>Schema, Update<Feature>Schema } from '@/lib/validators/<feature>'

async function requireSession() {
  const session = await createAuth(env.DB).api.getSession({ headers: getRequestHeaders() })
  if (!session) throw new Error('UNAUTHORIZED')
  return session
}

export const list<Features> = createServerFn({ method: 'GET' }).handler(async () => {
  await requireSession()
  const db = createDb(env.DB)
  return db.query.<feature>.findMany()
})

export const get<Feature> = createServerFn({ method: 'GET' })
  .inputValidator(z.object({ id: z.uuid() }))
  .handler(async ({ data }) => {
    await requireSession()
    const db = createDb(env.DB)
    return db.query.<feature>.findFirst({ where: (f, { eq }) => eq(f.id, data.id) })
  })

export const create<Feature> = createServerFn({ method: 'POST' })
  .inputValidator(Create<Feature>Schema)
  .handler(async ({ data }) => {
    const session = await requireSession()
    const db = createDb(env.DB)
    const id = crypto.randomUUID()
    const now = new Date()
    await db.insert(schema.<feature>).values({ id, ...data, createdAt: now, updatedAt: now })
    return { id }
  })

// update<Feature>, delete<Feature> follow the same pattern
```

### 4. Route — `src/routes/_authed/<feature>.tsx`

```tsx
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import { create<Feature>, list<Features> } from '@/server/<feature>/<feature>.server'

export const Route = createFileRoute('/_authed/<feature>')({
  loader: async ({ context }) => {
    return context.queryClient.ensureQueryData({
      queryKey: ['<feature>', 'list'],
      queryFn: () => list<Features>(),
    })
  },
  component: <Feature>Page,
})

function <Feature>Page() {
  const { data } = useQuery({ queryKey: ['<feature>', 'list'], queryFn: () => list<Features>() })
  const queryClient = useQueryClient()
  const m = useMutation({
    mutationFn: (input: { /* ... */ }) => create<Feature>({ data: input }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['<feature>'] }),
  })
  // ...
}
```

### 5. Components — `src/components/<feature>/`

- `<feature>-list.tsx` — list rendering
- `<feature>-form.tsx` — create/edit form using TanStack Form + Zod resolver. Both `e.preventDefault()` AND `e.stopPropagation()` in `onSubmit`.

Run `bunx shadcn add button input label form` if not already installed.

### 6. Verify

```bash
bun typecheck
bun check:fix
bun test       # if applicable
bun dev        # smoke test in browser
```

## Conventions

- Reuse `requireSession()` across CRUD handlers in the same feature.
- After mutations, invalidate the relevant query keys.
- Keep components under 150 lines.
- Don't reach across features through deep imports — extract to `src/lib/...` or `src/server/services/...`.
