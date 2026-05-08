#!/usr/bin/env bash
# Auto-format TypeScript/JavaScript/JSON/CSS files with Biome after Claude edits them.
# Runs synchronously so the formatted file is ready for Claude's next read.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

# Only process formattable files
[[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|mts|cts|json|jsonc|css)$ ]] && exit 0

# Skip generated and build directories
[[ "$FILE_PATH" =~ /(node_modules|\.output|\.wrangler|dist|build)/ ]] && exit 0

# Skip auto-generated files
[[ "$FILE_PATH" =~ routeTree\.gen\.ts$ ]] && exit 0
[[ "$FILE_PATH" =~ worker-configuration\.d\.ts$ ]] && exit 0
[[ "$FILE_PATH" =~ /drizzle/migrations/ ]] && exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0
bunx biome check --write "$FILE_PATH" 2>/dev/null || true

exit 0
