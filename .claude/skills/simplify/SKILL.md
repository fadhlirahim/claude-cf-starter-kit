---
name: simplify
description: Simplify and refine code while preserving behavior, leveraging the CF + Start stack
user-invocable: true
---

Analyze the specified code (or recent changes) and simplify it while preserving all functionality.

Use the code-simplifier agent for this skill.

Target: $ARGUMENTS

## Simplification Targets

1. **Dead code**: Unused imports, variables, functions, types.
2. **Nesting**: Early returns, guard clauses.
3. **Duplication**: Extract only when used 3+ times.
4. **Types**: Remove unnecessary generics, use inference (`$inferSelect`/`$inferInsert`).
5. **Control flow**: Flatten complex ternaries.
6. **Stack leverage**:
   - Manual `fetch` to provider URL → AI Gateway via `env.AI.run(..., { gateway: { id } })` or AI SDK with gateway `baseURL`
   - Manual `fetch` to own API → `createServerFn` consumed via TanStack Query
   - `useEffect` data fetching → `useQuery` + server function
   - `useState` for server state → `useQuery` / `useMutation`
   - Manual SQL strings → Drizzle relational queries
   - Manual auth checks → `_authed` layout / server-fn middleware
   - Manual MIME builds → `createEmail({...}).send(...)`
   - Manual R2 fetches → `env.MY_BUCKET.put/get/delete`
   - Hand-rolled retries in workflows → `step.do(name, { retries }, fn)`
   - Hand-rolled sleep → `step.sleep(name, duration)`
   - Module-scoped binding factories → per-request factories
   - `z.string().email()` → `z.email()`
   - `.merge()` → `.extend()`
   - `process.env` in worker code → `env` from `cloudflare:workers`

## Rules

- NEVER change behavior.
- NEVER add features, comments, or documentation.
- NEVER create abstractions for single-use code.
- Keep changes minimal and focused.
- Run `bun check:fix` after modifications.
- Explain each simplification briefly.
