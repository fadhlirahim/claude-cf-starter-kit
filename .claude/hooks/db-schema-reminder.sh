#!/usr/bin/env bash
# Remind Claude to run migrations or regen auth schema after schema/auth edits.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

# Drizzle schema modified → remind to generate migration and apply locally
if [[ "$FILE_PATH" =~ /db/schema\.ts$ ]]; then
	jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "Database schema was modified. Run: bun db:generate && bun db:migrate:local"}}'
	exit 0
fi

# better-auth config modified → remind to regenerate auth schema if plugins changed
if [[ "$FILE_PATH" =~ /server/auth\.ts$ ]]; then
	jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "better-auth config was modified. If you added/removed plugins, run: bun db:auth && bun db:generate && bun db:migrate:local"}}'
	exit 0
fi

# Zod validators modified → remind to typecheck server fns
if [[ "$FILE_PATH" =~ /lib/validators/.*\.ts$ ]]; then
	jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "Zod validator was modified. Verify server functions still type-check: bun typecheck"}}'
	exit 0
fi

exit 0
