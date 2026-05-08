---
name: cf-typegen
description: Regenerate worker-configuration.d.ts from wrangler.jsonc and re-typecheck
user-invocable: true
allowed-tools: ["Bash"]
---

Regenerate Cloudflare binding types.

`worker-configuration.d.ts` is auto-generated from `wrangler.jsonc`. Whenever a binding is added, removed, or renamed, this file MUST be regenerated or `Env` will be stale and TypeScript will silently miss errors.

## Process

```bash
bun cf-typegen
bun typecheck
```

If `typecheck` surfaces "Property 'X' does not exist on type 'Env'", a binding was referenced in code but is missing from `wrangler.jsonc`. Add it first.

## When to run

- After editing `wrangler.jsonc` (the `cf-binding-reminder.sh` hook will remind you).
- Before deploying a feature that adds a binding.
- After pulling main if the diff includes `wrangler.jsonc` changes.

## Conventions

- `worker-configuration.d.ts` is gitignored in this kit — it's a build artifact. Regenerate locally; don't commit.
- Don't hand-edit it (the `protect-sensitive.sh` hook blocks edits).
