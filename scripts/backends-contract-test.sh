#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKENDS_FILE="$ROOT_DIR/backends.json"

jq -e '
  .version == 1
  and (.workers | type == "object")
  and ([
    .workers.codex.implementation,
    .workers.codex["test-authoring-and-analysis"],
    .workers.claude["documentation-planning"],
    .workers.claude.review
  ] | all(.[]; (.provider | type == "string") and (.provider | length > 0) and (.model | type == "string") and (.model | length > 0) and (.reason | type == "string") and (.reason | length > 0)))
' "$BACKENDS_FILE" >/dev/null

if rg -n -i '5\.6 luna|gpt-5\.6-luna|sonnet|opus' "$ROOT_DIR/AGENTS.md" "$ROOT_DIR/CLAUDE.md"; then
    printf 'FAIL: AGENTS.md and CLAUDE.md must reference backends.json instead of model names\n' >&2
    exit 1
fi

printf 'Worker backend contract passed\n'
