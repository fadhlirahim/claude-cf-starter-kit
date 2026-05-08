---
name: deploy
description: Deploy the Worker to staging or production via wrangler
user-invocable: true
argument-hint: [stg|prod]
allowed-tools: ["Bash", "Read"]
---

Deploy: **$ARGUMENTS**

Production deploys are real. ASK THE USER for confirmation before pushing to prod, even when the command runs successfully on staging first.

## Preflight

1. Confirm the target — default to `stg` if `$ARGUMENTS` is empty or unrecognized.
2. Read `wrangler.jsonc` and confirm:
   - `name` matches the expected worker name for the target environment.
   - `compatibility_date` and `compatibility_flags: ["nodejs_compat"]` are set.
   - `routes` (or `*.workers.dev` default) targets the right domain.
3. Check secrets are set on the target:

```bash
wrangler secret list                 # prod (default)
wrangler secret list --env stg       # staging
```

`BETTER_AUTH_SECRET` is required. AI provider keys (`OPENAI_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`) are required only if AI SDK routes use them.

If a secret is missing, set it before deploying:

```bash
wrangler secret put BETTER_AUTH_SECRET
# (paste the secret when prompted; it never hits disk)
```

4. Confirm pending migrations:

```bash
wrangler d1 migrations list DB --remote
```

If there are unapplied migrations, run `/migrate` first — applying them after the deploy can break the running Worker.

## Deploy to staging

```bash
bun deploy:stg
```

This runs `WRANGLER_ENV=stg vite build && wrangler deploy --env stg`. The `vite.config.ts` is expected to swap bindings for stg via the cloudflare plugin's `config` callback (see `/setup` for the pattern, or vidcrafty's `vite.config.ts` for a worked example).

## Deploy to production

CONFIRM WITH THE USER FIRST. Then:

```bash
bun deploy
```

This runs `vite build && wrangler deploy`. Production worker name and routes come straight from `wrangler.jsonc`.

## Post-deploy

1. Tail logs to confirm the worker is healthy:

```bash
wrangler tail              # prod
wrangler tail --env stg    # staging
```

2. Hit the health/AI route and confirm a 200 response.
3. (For AI changes) Open the AI Gateway dashboard → **Logs** → confirm a request appears.

## Rollback

```bash
wrangler rollback              # interactive list of recent deployments
wrangler rollback <version-id>
```

CF retains a rolling history of recent deploys. Use this rather than re-deploying old source, which would re-run migrations.

## Conventions

- Don't deploy with uncommitted changes — `/push` first or stash. `git status` should be clean.
- Don't `wrangler deploy --force` past a divergence. Investigate the cause.
- Production secrets live in CF, not in `.dev.vars`. Don't paste prod secrets into local files.
- For first deploy of a binding, `bun cf-typegen` must have been run AFTER the binding was added to `wrangler.jsonc`, otherwise the worker will reference a binding that doesn't exist.
