#!/usr/bin/env bash
# When wrangler.jsonc is edited, remind Claude to regenerate binding types.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

# wrangler config changed → bindings may have shifted
if [[ "$FILE_PATH" =~ wrangler\.(jsonc|toml)$ ]]; then
	jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "wrangler config changed. Run: bun cf-typegen — then bun typecheck. New/renamed bindings will not appear on env until worker-configuration.d.ts is regenerated."}}'
	exit 0
fi

exit 0
