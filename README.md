# Claude Cloudflare Starter Kit

A Claude Code configuration kit for building Cloudflare-native fullstack TypeScript applications. Drop these files into any project to get an opinionated AI development environment with deterministic quality gates and a working `/setup` skill that bootstraps a TanStack Start + Cloudflare Workers app with a Workers-AI-through-AI-Gateway route in under five minutes.

This is **not** an app template with source code. It's the `.claude/` directory, `CLAUDE.md`, and `biome.json` that teach Claude Code how to build correctly in this stack — plus a `/setup` slash command that scaffolds the runnable app on demand.

## The Stack

| Layer | Technology |
|-------|-----------|
| Runtime | [Cloudflare Workers](https://developers.cloudflare.com/workers/) (Workers Static Assets) |
| Framework | [TanStack Start](https://tanstack.com/start) on `@cloudflare/vite-plugin` |
| Routing | [TanStack Router](https://tanstack.com/router) (file-based) |
| Data | [TanStack Query](https://tanstack.com/query) |
| API | TanStack Start `createServerFn` + Zod 4 (no tRPC) |
| Forms | [TanStack Form](https://tanstack.com/form) + Zod 4 |
| Auth | [better-auth](https://better-auth.com) (Drizzle adapter, D1) |
| Database | [Drizzle ORM](https://orm.drizzle.team) + [Cloudflare D1](https://developers.cloudflare.com/d1/) |
| Storage | [Cloudflare R2](https://developers.cloudflare.com/r2/) |
| Async | [Cloudflare Workflows](https://developers.cloudflare.com/workflows/) |
| Cron | wrangler `triggers.crons` + `scheduled` handler |
| Email | [Cloudflare Email Sending](https://developers.cloudflare.com/email-routing/email-workers/) |
| AI | [Workers AI](https://developers.cloudflare.com/workers-ai/) through [AI Gateway](https://developers.cloudflare.com/ai-gateway/) |
| UI | [shadcn/ui](https://ui.shadcn.com) (new-york), Tailwind v4, lucide |
| Validation | [Zod 4](https://zod.dev) |
| Linting | [Biome](https://biomejs.dev) |
| Test | vitest + `@cloudflare/vitest-pool-workers` |
| Pkg manager | [bun](https://bun.sh) |

## What's Included

```
CLAUDE.md                          # Project conventions + anti-patterns for the CF stack
README.md                          # This file
biome.json                         # Formatting + linting (CF globals declared)
package.json                       # Scripts (dev, deploy, db:*, cf-typegen, ...)
install.sh                         # Idempotent installer
.env.example                       # `.dev.vars` template (CF secrets)
.gitignore                         # Worker-aware (.wrangler/, worker-configuration.d.ts, ...)
.claude/
  settings.json                    # Permissions, hooks, plugins
  hooks/                           # 9 lifecycle hook scripts
    protect-sensitive.sh           #   Block writes to .dev.vars, migrations, generated files
    auto-format.sh                 #   Biome on every file edit
    db-schema-reminder.sh          #   Reminders after schema/auth edits
    cf-binding-reminder.sh         #   Remind to `bun cf-typegen` after wrangler.jsonc edits
    git-context.sh                 #   Inject git state into every prompt
    session-context.sh             #   Re-inject CF + Start patterns after compaction
    post-implement-review.sh       #   Force review when 3+ files changed
    notify-macos.sh                #   Permission-prompt notifications
    stop-notify.sh                 #   Done-with-task notifications
  skills/                          # 25 slash commands
    setup/SKILL.md                 #   /setup — bootstrap the app from zero
    add-server-fn/SKILL.md         #   /add-server-fn — Zod-validated server function
    add-route/SKILL.md             #   /add-route — file-based route
    add-d1-table/SKILL.md          #   /add-d1-table — Drizzle table + migration
    add-r2/SKILL.md                #   /add-r2 — R2 binding + helpers + signed URLs
    add-workflow/SKILL.md          #   /add-workflow — Workflow class + binding
    add-cron/SKILL.md              #   /add-cron — cron expression + scheduled dispatch
    add-email/SKILL.md             #   /add-email — Email Sending binding + helper
    add-ai-route/SKILL.md          #   /add-ai-route — AI Gateway-routed AI server fn
    add-shadcn/SKILL.md            #   /add-shadcn — install shadcn components
    add-auth-provider/SKILL.md     #   /add-auth-provider — wire a social provider
    migrate/SKILL.md               #   /migrate — generate + apply Drizzle migrations
    deploy/SKILL.md                #   /deploy — wrangler deploy (stg/prod gated)
    cf-typegen/SKILL.md            #   /cf-typegen — refresh worker-configuration.d.ts
    push/SKILL.md                  #   /push — commit, push, create PR
    commit/SKILL.md                #   /commit — auto-generated commit message
    review/SKILL.md                #   /review — code review
    simplify/SKILL.md              #   /simplify — reduce complexity
    refactor/SKILL.md              #   /refactor — safe refactoring
    debug/SKILL.md                 #   /debug — systematic debugging
    test/SKILL.md                  #   /test — write or run tests
    docs/SKILL.md                  #   /docs — Context7 doc lookup
    scaffold/SKILL.md              #   /scaffold — fullstack feature generation
    compound/SKILL.md              #   /compound — extract session learnings
    clean-branches/SKILL.md        #   /clean-branches — prune stale branches
  agents/                          # 4 specialist subagents
    code-reviewer.md
    code-simplifier.md
    test-writer.md
    fullstack-builder.md
```

## How It Works

The kit operates on three reinforcing layers.

### 1. CLAUDE.md — The Brain

A comprehensive instruction file that teaches Claude Code the project's conventions:

- **Project structure** — where every file belongs.
- **Stack-specific patterns** — version-specific API details: TanStack Start `createServerFn` with `.inputValidator(...)`, Drizzle on D1 with `createDb(d1)` factory, better-auth's `tanstackStartCookies()` plugin order, AI Gateway routing rule, Workflow `step.do` pattern, Cron dispatch by `event.cron`.
- **Anti-patterns** — explicit "don't do this" rules for the most common Cloudflare/Start mistakes (`process.env` in worker code, secrets in `wrangler.jsonc` `vars`, hand-edited `worker-configuration.d.ts`, AI calls that bypass the gateway, non-deterministic Workflow IDs, …).
- **Code examples** — copy-paste patterns for routes, server functions, AI calls, R2 access, Workflows, email send, cron dispatch.

### 2. Hooks — Automated Quality Gates

Shell scripts in `.claude/hooks/` wired to lifecycle events in `settings.json`. Unlike CLAUDE.md instructions (which are advisory), hooks are **deterministic** — they run every time, guaranteed.

| Event | Hook | What It Does |
|-------|------|-------------|
| **UserPromptSubmit** | `git-context.sh` | Injects current branch, recent commits, and uncommitted files into every prompt. |
| **PreToolUse** (Write\|Edit) | `protect-sensitive.sh` | **Blocks** writes to `.dev.vars`, `routeTree.gen.ts`, `worker-configuration.d.ts`, `drizzle/migrations/*.sql`, `.wrangler/`. |
| **PostToolUse** (Write\|Edit) | `auto-format.sh` | Runs `bunx biome check --write` on every file Claude edits. Skips generated files. |
| **PostToolUse** (Write\|Edit) | `db-schema-reminder.sh` | When `schema.ts`, `auth.ts`, or a Zod validator is modified, reminds about migrations/typecheck. |
| **PostToolUse** (Write\|Edit) | `cf-binding-reminder.sh` | When `wrangler.jsonc` changes, reminds to run `bun cf-typegen`. |
| **SessionStart** (compact) | `session-context.sh` | Re-injects critical CF + Start patterns after context compaction. |
| **Stop** | `post-implement-review.sh` | When 3+ TS source files changed, **blocks** Claude from finishing and asks for `/simplify` + `/review` + typecheck. Loop-safe. |
| **Stop** | `stop-notify.sh` | macOS notification when Claude finishes. |
| **Notification** | `notify-macos.sh` | Distinct sounds for permission prompts vs idle prompts. |

### 3. Skills & Agents — Workflows on Demand

**Slash commands** for the daily workflow:

| Command | What It Does |
|---------|-------------|
| `/setup` | **The headline.** Bootstraps a working app from zero: Vite + cloudflare plugin, wrangler config, D1, AI Gateway-routed Workers AI route, better-auth on D1, Drizzle, Tailwind v4, shadcn. Verifies with a real Workers AI call through AI Gateway. |
| `/add-server-fn name` | Adds a Zod-validated TanStack Start server function. |
| `/add-route path` | Adds a file-based route (public, authed, or top-level). |
| `/add-d1-table name` | Adds a Drizzle table, generates migration, applies locally. |
| `/add-r2 bucket` | Adds an R2 binding + helper functions + signed-URL signer. |
| `/add-workflow name` | Adds a `WorkflowEntrypoint` class + binding + named export. |
| `/add-cron "expr" handler` | Adds a cron expression + scheduled-handler dispatch case. |
| `/add-email [template]` | Wires `send_email` binding + `createEmail` helper + (optional) template. |
| `/add-ai-route name` | Adds a Workers AI or AI SDK server function — routed through AI Gateway. |
| `/add-shadcn comp...` | Installs shadcn components into `src/components/ui/`. |
| `/add-auth-provider name` | Wires a better-auth social provider (GitHub, Google, ...). |
| `/migrate "change"` | Generates Drizzle migration, applies locally, gates `--remote` on user confirmation. |
| `/deploy [stg\|prod]` | `wrangler deploy` with secret/migration preflight checks. |
| `/cf-typegen` | Refreshes `worker-configuration.d.ts`. |
| `/scaffold feature` | Generates an end-to-end CRUD feature: schema → migration → server fns → route → components. |
| `/push` | Commits, pushes, creates PR with grouped changes and test plan. |
| `/commit [hint]` | Auto-generates a commit message matching repo style. |
| `/review` | Forks a subagent against a 15-point CF + Start checklist. |
| `/simplify [target]` | Reduces complexity by leveraging stack patterns. |
| `/refactor target` | Plans and executes a refactor with verification. |
| `/debug "issue"` | Walks the data flow with a CF-specific common-causes checklist. |
| `/test target` | Writes or runs vitest tests (with workers-pool patterns). |
| `/docs library topic` | Looks up current docs via Context7. |
| `/compound` | Extracts session learnings into `CLAUDE.md`. |
| `/clean-branches` | Prunes local branches deleted from remote. |

**Specialist agents** for delegation:

| Agent | When It's Used |
|-------|---------------|
| `code-reviewer` | Reviews changes for security, types, conventions, AI Gateway routing, binding access, secret handling. |
| `code-simplifier` | Reduces nesting, removes dead code, swaps manual code for stack patterns. |
| `test-writer` | Generates vitest tests using workers-pool, D1 in-memory, AI mocks at boundaries. |
| `fullstack-builder` | Builds complete features in the correct order: schema → migration → server fn → route → components. |

## Install

The fastest way is the install script. It works for both fresh projects and existing repos. Run it from the directory you want the kit applied to:

```bash
curl -fsSL https://raw.githubusercontent.com/fadhlirahim/claude-cloudflare-starter-kit/main/install.sh | bash
```

Or pass a target directory:

```bash
curl -fsSL https://raw.githubusercontent.com/fadhlirahim/claude-cloudflare-starter-kit/main/install.sh | bash -s -- /path/to/your-project
```

Prefer to inspect first? Clone and run locally:

```bash
git clone https://github.com/fadhlirahim/claude-cloudflare-starter-kit.git
cd /path/to/your-project
bash /path/to/claude-cloudflare-starter-kit/install.sh
```

### What the installer does

- **Kit-owned files** (`CLAUDE.md`, `biome.json`, `.claude/**`) are written into your project. If a file already exists with different content, the existing file is renamed to `<file>.bak` first — nothing is silently clobbered.
- **User-owned files** (`package.json`, `.gitignore`) are **never** overwritten. If they already exist, the installer prints suggested additions for you to merge by hand.
- `.env.example` is copied only if you don't already have one.
- Hook scripts are made executable.
- Re-running the installer is safe — files identical to the kit are reported as unchanged.

After install:

1. Open `CLAUDE.md` and replace `[App Name]` with your project name.
2. Restart Claude Code so it picks up the new settings and hooks.
3. **Fresh project?** Run `/setup` — it bootstraps the TanStack Start + Cloudflare Workers app, wires better-auth on D1, scaffolds an AI Gateway-routed Workers AI route, and verifies with a real Workers AI call. Skip if you already have `src/`.
4. **Existing project?** Use the `/add-*` skills (`/add-d1-table`, `/add-r2`, `/add-workflow`, `/add-cron`, `/add-email`, `/add-ai-route`, `/add-server-fn`, `/add-shadcn`, `/add-auth-provider`) to add primitives one at a time.
5. Local secrets go in `.dev.vars` (the kit blocks automated edits — fill it manually). Generate a `BETTER_AUTH_SECRET` with `openssl rand -base64 32`.

### Daily Workflow

```
You: /scaffold posts
  → Drizzle table, migration, validators, server fns, route, components
  → Auto-format, db-schema-reminder, cf-binding-reminder fire as files land

You: /review
  → code-reviewer agent runs the 15-point CF + Start checklist

You: /simplify src/server/posts/
  → Replaces manual patterns with stack patterns (server fns, gateway routing, ...)

You: /push
  → Commits, pushes, creates PR with grouped changes and test plan

You: /deploy stg
  → Builds, checks secrets, applies pending migrations after confirmation, deploys
```

## Permissions

Pre-approved (won't prompt):

- `bun *`, `bunx biome*`, `bunx drizzle-kit*`, `bunx @better-auth/cli*`, `bunx shadcn*`
- `wrangler types`, `wrangler dev`, `wrangler tail`, `wrangler whoami`, `wrangler d1 list/info`, `wrangler d1 migrations list`, `wrangler d1 migrations apply * --local`, `wrangler d1 execute * --local`, `wrangler r2 bucket list`, `wrangler kv namespace list`, `wrangler ai gateway *`
- Standard `git` (status, diff, log, add, commit, branch, checkout, stash, push, fetch, worktree, init), `gh pr *`
- Context7 MCP

Hard-denied (require explicit override):

- `rm -rf /`, `rm -rf ~`, `git push --force`, `git reset --hard`, `git clean -f`
- `wrangler d1 execute --remote` — production data ops
- `wrangler secret delete`, `wrangler delete`, `wrangler r2 bucket delete`, `wrangler d1 delete` — destructive resource ops

## Customization

### Conventions

Edit `CLAUDE.md` directly. Sections are clearly demarcated — modify patterns, add anti-patterns, change project structure.

### Skills

```yaml
---
name: your-skill
description: When to use this skill
user-invocable: true
argument-hint: what $ARGUMENTS represents
allowed-tools: ["Bash", "Read"]   # optional
context: fork                      # optional — fork to subagent
agent: general-purpose             # optional — pin agent type
---

Instructions for Claude when this skill runs.
Reference user input as $ARGUMENTS.
```

### Agents

```yaml
---
name: your-agent
description: When Claude should delegate to this agent
tools: Read, Grep, Glob, Bash, Edit, Write
model: inherit
---

System prompt for the agent.
```

### Hooks

```bash
#!/usr/bin/env bash
# .claude/hooks/my-hook.sh
INPUT=$(cat)  # JSON from stdin: { tool_input, session_id, ... }
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit 0 = proceed; Exit 2 = BLOCK (stderr shown to Claude).
echo "Blocked: reason" >&2 && exit 2

# Or output additionalContext to inject a reminder:
jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "..."}}'
```

Wire it up in `.claude/settings.json` under the appropriate event matcher.

## Key Design Decisions

**Why no tRPC?** TanStack Start's native server functions cover the same ground (typed RPC, Zod validation, server-only execution) with one fewer dependency and zero config. tRPC is added easily later if a project's API surface grows complex enough to warrant a router abstraction.

**Why Workers (not Pages)?** Cloudflare Pages is being folded into Workers Static Assets; Workers is the modern, supported deployment target for SSR frameworks. Tanstack Start has first-class support via `@cloudflare/vite-plugin`.

**Why AI Gateway as a hard rule?** Without it: no caching (every prompt hits the model), no per-call logs (debugging blind), no spend visibility, no rate-limit shaping. Adding it later means rewriting every AI call. The gateway is one configuration line in `wrangler.jsonc` plus a `gateway: { id }` option on each call — there's no reason not to wire it on day one.

**Why D1 instead of Postgres?** D1 ships in the Worker runtime (no networking hop, no separate billing, no separate ops). For most apps starting out, D1's per-row cost and query latency beat managed Postgres. When you outgrow D1, you swap the Drizzle driver — the rest of the code is unchanged.

**Why Biome over ESLint + Prettier?** Single binary, single config, 10-25x faster, built-in import sorting and React hooks rules. The kit's auto-format hook runs synchronously without slowing the session.

**Why so many anti-patterns?** Each one is a real mistake AI assistants commonly make on the Cloudflare stack. The anti-patterns section is the highest-leverage part of `CLAUDE.md` — it prevents the most common failures (binding access via `process.env`, secrets in vars, AI calls bypassing the gateway, non-idempotent Workflow IDs, …) before they happen.

## Requirements

- [Bun](https://bun.sh) (package manager and runtime)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [GitHub CLI](https://cli.github.com/) (`gh`) — for `/push` and `/clean-branches`
- A Cloudflare account with `wrangler` authenticated (`wrangler login`)
- [Context7 MCP server](https://github.com/upstash/context7) (optional, for `/docs`)
