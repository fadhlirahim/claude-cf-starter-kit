---
name: add-shadcn
description: Install one or more shadcn/ui components into src/components/ui
user-invocable: true
argument-hint: component-name[ component-name...]
allowed-tools: ["Bash"]
---

Install shadcn components: **$ARGUMENTS**

## Process

1. Verify `components.json` exists at the repo root. If not, run `bunx shadcn@latest init` first (interactively confirm: style new-york, base color neutral, CSS file `src/styles/app.css`, alias `@/*` to `src/*`).

2. Install:

```bash
bunx shadcn@latest add $ARGUMENTS
```

This writes files under `src/components/ui/<name>.tsx` per the aliases in `components.json`.

3. shadcn-generated files use default exports — Biome's `noDefaultExport` is already disabled for `src/components/ui/**` via the `biome.json` override. Don't re-format them aggressively.

4. Verify:

```bash
bun typecheck
bun check
```

## Conventions

- Don't edit shadcn-generated files in place when you need a variant. Copy to `src/components/<feature>/<name>.tsx` and customize.
- `cn()` lives at `src/lib/utils.ts`. shadcn imports it from `@/lib/utils` — don't move it.
- Icons come from `lucide-react`. Don't add another icon library.

## Common installs

- **Forms**: `button input label textarea select checkbox radio-group form`
- **Layout**: `card dialog sheet tabs separator scroll-area`
- **Feedback**: `alert toast tooltip progress skeleton`
- **Data**: `table badge avatar dropdown-menu`

For toasts, this kit ships `sonner` — use `<Toaster />` from `sonner` directly, not shadcn's `toast` (which is being phased out by shadcn upstream).
