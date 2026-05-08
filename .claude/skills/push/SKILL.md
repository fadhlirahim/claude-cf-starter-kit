---
name: push
description: Commit all changes, push to remote, and create a pull request with a comprehensive description
user-invocable: true
argument-hint: [optional PR title or description]
allowed-tools: ["Bash", "Read", "Glob", "Grep"]
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged): !`git diff HEAD --stat`
- Current branch: !`git branch --show-current`
- Recent commits on branch: !`git log main..HEAD --oneline 2>/dev/null || git log --oneline -5`
- Remote tracking: !`git rev-parse --abbrev-ref @{u} 2>/dev/null || echo "no upstream"`

## Your Task

Create a commit, push, and open a PR for the current changes. Steps:

### 1. Analyze Changes

- Run `git status` to see all untracked and modified files
- Run `git diff HEAD` to see the full diff
- Run `git log main..HEAD --oneline` to see all commits on this branch
- Understand the full scope (not just the latest commit — ALL commits on the branch)

### 2. Create Branch (if needed)

If currently on `main` or `master`:
- Create a descriptive branch: `git checkout -b <type>/<short-description>`
- Types: `feat/`, `fix/`, `refactor/`, `chore/`, `docs/`

### 3. Stage and Commit

- Stage relevant files (prefer specific files over `git add -A`)
- NEVER stage `.dev.vars`, `.env`, credentials, or secrets
- Draft a commit message that:
  - Follows conventional commits (`feat:`, `fix:`, `refactor:`, `chore:`)
  - Matches the repository's existing commit style
  - Focuses on WHY, not WHAT
  - **Does NOT include `Co-Authored-By: Claude`** — the user has explicitly opted out of Claude co-authorship
- Use a HEREDOC for the commit message

### 4. Push

- Push with upstream tracking: `git push -u origin <branch-name>`
- If push fails due to divergence, inform the user — do NOT force push

### 5. Create Pull Request

```bash
gh pr create --title "<concise title under 70 chars>" --body "$(cat <<'EOF'
## Summary

<1-3 bullet points describing what this PR does and why>

## Changes

<grouped list by area — e.g., DB / Server fns / Routes / UI / wrangler / Workflows>

## Test Plan

- [ ] <specific verification steps>
- [ ] Types pass (`bun typecheck`)
- [ ] Lint passes (`bun check`)
- [ ] Tests pass (`bun test`)
- [ ] (If bindings changed) `bun cf-typegen` ran clean
- [ ] (If schema changed) Migration applied locally without errors

EOF
)"
```

### 6. Report

Output the PR URL.

## Rules

- Analyze ALL commits on the branch for the PR description, not just the latest.
- Keep PR title under 70 chars; use the body for details.
- Group changes by area in the description.
- Include specific test plan items, not just "test it".
- NEVER force push.
- NEVER push to main/master directly.
- NEVER include `Co-Authored-By: Claude` (user preference).
- If user provided $ARGUMENTS, use it to inform the PR title/description.
