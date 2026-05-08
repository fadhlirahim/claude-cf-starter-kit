---
name: compound
description: Extract and persist learnings from the current session into CLAUDE.md
user-invocable: true
---

Review the work done in this session and extract learnings that compound future productivity.

## Process

1. **Review changes**: `git diff`, `git log` for the session's work
2. **Identify patterns** worth keeping:
   - Architectural decisions made
   - Cloudflare-specific gotchas (binding access, AI Gateway routing, Workflow ID determinism, cron dispatch)
   - Stack quirks (Zod 4 changes, TanStack Start server-fn shape, better-auth adapter behavior)
   - Common mistakes that were fixed
   - Conventions established (file naming, factory patterns, validator placement)
3. **Update CLAUDE.md**: Append new conventions or anti-patterns if broadly applicable
4. **Verify**: Make sure additions don't duplicate existing instructions; tighten the wording

## What to Compound

- New file patterns or naming conventions
- New integration patterns between stack layers (server fn ↔ Drizzle ↔ better-auth ↔ AI Gateway)
- Debugging insights specific to Cloudflare (cold start surprises, D1 transaction semantics, KV consistency, R2 metadata gotchas)
- Performance patterns discovered (D1 batch ops, Workflow step-grouping, TanStack Query stale-time tuning)
- Auth/security patterns

## What NOT to Compound

- One-off task-specific details
- Things Claude already does correctly without explicit instruction
- Speculative conclusions from a single case
- Anything already in `CLAUDE.md`
