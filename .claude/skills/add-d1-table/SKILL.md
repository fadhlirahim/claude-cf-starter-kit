---
name: add-d1-table
description: Add a Drizzle table to the D1 schema, generate the migration, and apply it locally
user-invocable: true
argument-hint: table-name
---

Add a D1 table: **$ARGUMENTS**

## Process

1. **Edit `src/server/db/schema.ts`** — append the table below the better-auth block:

```ts
import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core'
import { relations } from 'drizzle-orm'

export const <name> = sqliteTable('<name>', {
  id: text('id').primaryKey(),
  // ... your columns
  // Common SQLite types in this stack:
  //   text('field')
  //   integer('field', { mode: 'boolean' })
  //   integer('field', { mode: 'timestamp' })
  //   real('field')
  //   blob('field')
  createdAt: integer('createdAt', { mode: 'timestamp' }).notNull(),
  updatedAt: integer('updatedAt', { mode: 'timestamp' }).notNull(),
})

// Define relations even if just one — better-auth's adapter benefits
export const <name>Relations = relations(<name>, (/* { one, many } */) => ({
  // example: user: one(user, { fields: [<name>.userId], references: [user.id] }),
}))
```

2. **Generate migration**:

```bash
bun db:generate
```

This writes `drizzle/migrations/0NNN_<auto-name>.sql`. Open it and skim — confirm column types match expectations.

3. **Apply locally**:

```bash
bun db:migrate:local
```

This hits the Miniflare D1 instance under `.wrangler/state/`.

4. **(Later) Apply to staging or production** — use `/migrate` skill, which gates `--remote` calls behind confirmation.

5. **Add validators** (optional but encouraged):

```ts
// src/lib/validators/<name>.ts
import { z } from 'zod/v4'

export const <Name>Schema = z.object({
  id: z.uuid(),
  // ... mirror schema.ts shape
})

export const Create<Name>Schema = <Name>Schema.omit({ id: true })
export const Update<Name>Schema = <Name>Schema.partial().extend({ id: z.uuid() })

export type <Name> = z.output<typeof <Name>Schema>
```

6. **Verify**:

```bash
bun typecheck
```

## Conventions

- Table names: lower-case, singular (matches better-auth convention: `user`, `session`, `post`).
- Column names: camelCase in SQLite (matches better-auth's `createdAt`, `updatedAt`).
- Always include `id`, `createdAt`, `updatedAt`.
- Use `references(() => other.id, { onDelete: 'cascade' })` for FK + cascade.
- D1 has limited transaction semantics — `db.transaction(...)` runs as a batched D1 transaction. Don't depend on Postgres-level isolation.
- Don't hand-edit `drizzle/migrations/*.sql` (the protect-sensitive hook blocks it). Re-run `bun db:generate` after schema changes.
