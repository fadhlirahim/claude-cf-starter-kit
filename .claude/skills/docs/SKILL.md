---
name: docs
description: Look up current documentation for any library in the stack via Context7
user-invocable: true
argument-hint: library-name topic
---

Look up documentation for: $ARGUMENTS

## Process

1. Resolve the library ID with `mcp__context7__resolve-library-id`.
2. Query docs with `mcp__context7__query-docs` for the topic.
3. Present the relevant documentation with code examples.

## Stack Libraries

| Library | Notes |
|---------|-------|
| tanstack-start | SSR framework, server functions, deployment |
| tanstack-router | File-based routing, search params, loaders |
| tanstack-query | Queries, mutations, suspense, prefetching |
| tanstack-form | Form state, validation, field arrays |
| better-auth | Auth setup, providers, sessions, plugins, Drizzle adapter |
| drizzle-orm | Schema, queries, migrations, relations, D1 adapter |
| zod | Schemas, validation (use v4 docs) |
| ai-sdk | `@ai-sdk/openai`, `@ai-sdk/google`, streaming |
| cloudflare-workers | Workers runtime, bindings, env |
| cloudflare-d1 | D1 SQL, migrations, sessions |
| cloudflare-r2 | R2 binding, S3 API |
| cloudflare-workers-ai | Models, gateway option, streaming |
| cloudflare-ai-gateway | Routing, caching, logs |
| cloudflare-workflows | WorkflowEntrypoint, step.do, sleep |
| cloudflare-email | send_email binding, MIME shape |
| wrangler | CLI, config, secrets, types |
| biome | Linting, formatting, configuration |
| vitest | Test runner, assertions |
| vitest-pool-workers | Workers-bound test pool |
| shadcn | CLI, components.json, theming |
| tailwind | v4 features, @theme blocks |

## When NOT to use this

- For project-internal questions (read the code).
- For "how do I" questions answered in `CLAUDE.md`.
- For general programming concepts (no library lookup needed).
