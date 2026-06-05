---
name: security-review
description: Adversarial security review of changes against the CF + Start attack surface — threat-model, scan, verify, rank
user-invocable: true
context: fork
agent: general-purpose
argument-hint: [files or PR scope]
---

Run an **adversarial** security review of the changes in this project. Unlike `/review` (quality + convention adherence), this asks one question per finding: **can an attacker abuse this?** Methodology borrowed from Anthropic's defending-code reference harness — threat-model → scoped scan → verify-then-trust → rank — retargeted from C/C++ memory safety to this stack's real vuln classes (authz, IDOR, injection, secrets, SSRF).

Scope: `git diff HEAD` (or the files / PR in $ARGUMENTS). Review the CHANGE and the surface it touches, not the whole repo.

## Process

### 1. Threat-model the change (scope the surface)
Before scanning, write 3-5 bullets: what does this change expose? New server function (untrusted input boundary)? A D1 query keyed by a user-supplied id (IDOR surface)? An R2 key, a WS room, an AI prompt, a new secret? Identify the **trust boundaries** the diff crosses — that's where bugs live. Everything below is scoped to those boundaries.

### 2. Scan against the stack's vuln classes
Walk the touched surface against this checklist. These are ordered by how often they're the real, high-impact bug in this stack — broken access control first.

**A. Broken access control / authz (highest impact)**
- Server function reads/writes a record by id WITHOUT verifying the row belongs to the session user/org → **IDOR**. `db.query.x.findFirst({ where: eq(x.id, data.id) })` with no tenant scope is the canonical bug.
- Server function performs a privileged action with no session gate, or the gate is `auth.api.getSession()` WITHOUT `getRequestHeaders()` (session reads anonymous → guard silently passes).
- Sensitive data fetched in a route `loader` (runs on the client too) instead of a gated server function.
- Protected page not under the `_authed` layout, or `beforeLoad` guard bypassable.
- Mass assignment: a `create`/`update` server fn spreads user input into a row, letting the client set `role`, `plan`, `orgId`, `userId`. better-auth sensitive `additionalFields` must be `input: false`.

**B. IDOR / tenancy on every resource**
- D1: every query on a user-owned table scoped by `orgId`/`userId`, not just `id`.
- R2: object keys namespaced (`<orgId>/...`) AND ownership re-checked on read — a namespaced key is not an authz check if the id is guessable.
- Realtime: the `SyncRoom` WS upgrade authenticated AND the room id namespaced by tenant (`idFromName(\`${orgId}:${room}\`)`). An un-namespaced room is cross-tenant data leakage over WebSocket.

**C. Secrets & server/client boundary**
- No secret in `wrangler.jsonc` `vars` (those are PUBLIC at runtime). Secrets only via `wrangler secret put` / `.dev.vars`.
- `.dev.vars` not committed; no secret literal in any tracked file.
- `import { env } from 'cloudflare:workers'` never reaches a route component/client file → would bundle bindings/secrets into the client. Check imports in `src/routes/**` and `src/components/**`.
- No secret in `console.log` / error responses returned to the client.

**D. Injection**
- SQL: Drizzle relational queries are safe; a raw `sql\`...${userInput}...\`` template with interpolation is NOT. Flag any raw SQL built from user input.
- XSS: `dangerouslySetInnerHTML`, or AI/markdown/user content rendered without sanitization.
- Prompt injection: untrusted input concatenated into an AI prompt where the model's output then drives an action (DB write, email, tool call). Treat AI output as untrusted.

**E. SSRF & outbound**
- Any server-side `fetch`/R2 fetch/webhook with a user-controlled URL or host → SSRF. Must allowlist.
- AI calls bypass the gateway (direct provider URL) → leaks keys, loses rate shaping.

**F. Input validation**
- Every server function has `.inputValidator(zodSchema)`; no handler trusts raw `data`.
- Zod strict where it matters (`z.strictObject` for request bodies that map to rows).

**G. Auth & session hardening**
- `BETTER_AUTH_SECRET` from a CF secret, not vars. `tanstackStartCookies()` LAST in the plugin chain (cookie handling breaks otherwise).
- Social provider secrets not leaked; redirect URIs constrained.
- State-changing operations are POST server fns, not GET (CSRF/replay surface).

**H. Abuse & cost**
- Email: per-action rate limiting given the 1000/day quota — an unauthenticated trigger is a quota-drain DoS.
- AI: cost-abuse on any endpoint that calls the model from unauthenticated or unthrottled input.
- Signup/auth endpoints: brute-force / enumeration surface.

**I. Info leakage & error handling**
- Stack traces / internal errors not returned to the client.
- No `catch {}` that swallows a security-relevant failure (an auth check that errors must fail closed, not open).

### 3. Verify before you trust (the false-positive filter)
This is the harness's core discipline. For EACH candidate finding:
- Write the concrete **exploit path**: the actual request/steps an attacker takes to abuse it. If you cannot articulate a realistic path, DROP or downgrade it — do not report speculative findings.
- Then **try to refute your own finding**: is there an upstream guard (the `_authed` layout, a middleware, a DB constraint) that already closes it? If a guard exists, drop it. Only findings that survive this adversarial pass get reported.
- Where feasible, state how to confirm it live against `bun dev` (e.g., "call the server fn with another org's id"). Don't run exploits automatically — propose them.

### 4. Rank and report
For each surviving finding:
- **Severity**: CRITICAL / HIGH / MEDIUM / LOW — by impact × exploitability, not by code smell.
- `file:line`, the vuln class (e.g., "IDOR / broken access control"), the **exploit path**, and a concrete fix (ideally a diff).
- Group by severity, CRITICAL first.

End with a verdict: **BLOCK** (ship-stopping vuln), **FIX BEFORE MERGE**, or **CLEAR** (no exploitable issue found in the reviewed surface). State explicitly what surface you did and did NOT cover.

## Conventions

- Adversarial, not advisory. Report what an attacker can DO, with the steps — not "this could be more secure."
- No speculative findings. A finding without an exploit path is noise; the verify-then-refute pass in step 3 is mandatory.
- Scoped to the diff's trust boundaries. This is not a whole-repo audit — say so in the verdict.
- Complements, doesn't replace, `/review`. Run `/review` for correctness/conventions; run this for exploitability.
- Out of scope (by design): memory-safety, native/WASM fuzzing, dependency CVEs. This stack doesn't have the first two; use `bun audit` / Dependabot for the third.
