---
name: refactor
description: Refactor code while maintaining identical behavior
user-invocable: true
argument-hint: target code or area
---

Refactor the specified code area while maintaining identical behavior: $ARGUMENTS

## Process

1. **Read** the target code and any tests
2. **Identify** the refactoring target:
   - Extract function/component
   - Move file to better location
   - Rename for clarity
   - Split large file
   - Consolidate scattered related code
   - Replace ad-hoc binding access with the per-request factory pattern (`createDb(d1)`, `createAuth(d1)`, `createEmail({...})`)
3. **Plan** the refactoring steps and share with the user before executing
4. **Execute** incrementally — one change at a time
5. **Verify** after each step:

```bash
bun typecheck && bun check
bun test       # if tests exist for the target
```

If bindings or `wrangler.jsonc` were touched, also `bun cf-typegen`.

## Rules

- Behavior must be IDENTICAL after refactoring.
- If tests exist, they must pass without changes (unless the test itself is the target).
- Update all imports/references when moving or renaming.
- If no tests exist for the refactored code, write a basic regression test FIRST.
