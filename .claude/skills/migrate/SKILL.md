---
name: migrate
description: Generate and apply a Drizzle migration for D1 (local now, remote on confirmation)
user-invocable: true
argument-hint: description of schema change
---

Apply a database migration: **$ARGUMENTS**

## Process

1. **Read** current schema at `src/server/db/schema.ts`.
2. **Modify** the schema (add table, add column, alter relation). Don't hand-write migration SQL.
3. **Generate**:

```bash
bun db:generate
```

Inspect the generated `drizzle/migrations/000N_*.sql`. Confirm column types and constraints look right. SQLite does not support every ALTER — check for warnings about table rebuilds.

4. **Apply locally**:

```bash
bun db:migrate:local
```

5. **Update Zod validators** in `src/lib/validators/` if the API surface changed.
6. **Update server functions** that touch the changed columns. `bun typecheck` will surface gaps.
7. **Apply to remote (production)** — ASK THE USER FIRST:

```bash
bun db:migrate:remote
```

For staging:

```bash
wrangler d1 migrations apply <stg-db-name> --remote
```

This is a production operation. Confirm with the user before running. The wrangler `d1 execute --remote` is hard-denied in `settings.json`; `d1 migrations apply --remote` is allowed but should still get a confirmation.

8. **Verify**:

```bash
bun typecheck
bun check:fix
```

## Drizzle / D1 Conventions

- Table names: lower-case singular (`user`, `session`, `post`).
- Column names: camelCase in SQLite (matches better-auth's pattern).
- SQLite types: `text`, `integer({ mode: 'boolean' | 'timestamp' })`, `real`, `blob`.
- Always include `id`, `createdAt`, `updatedAt`.
- D1 has no Postgres-style transactions across statements — `db.transaction()` runs as a batched D1 transaction.
- D1's SQLite has limited `ALTER TABLE` support. Adding a NOT NULL column without a default is a rebuild.

## If Adding better-auth Plugin Tables

```bash
bun db:auth        # appends/updates auth tables in schema.ts
bun db:generate    # generates migration from the diff
bun db:migrate:local
```
