#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/codex-branch-review.yml"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local expected="$1"
    grep -Fq -- "$expected" "$WORKFLOW" \
        || fail "codex branch review workflow에 다음 계약이 없습니다: $expected"
}

assert_not_contains() {
    local unexpected="$1"
    grep -Fq -- "$unexpected" "$WORKFLOW" \
        && fail "신뢰되지 않은 PR 실행을 허용하는 계약이 있습니다: $unexpected"
}

assert_contains "      - 'codex/**'"
assert_contains "  pull_request:"
assert_contains "    types: [opened, synchronize, reopened]"
assert_contains "  workflow_dispatch:"
assert_contains "github.event_name == 'pull_request'"
assert_contains "github.event.pull_request.head.repo.full_name == github.repository"
assert_contains "github.event.pull_request.author_association"
assert_contains "shell: bash"
assert_not_contains "pull_request_target"

printf 'Codex branch review workflow contract passed\n'
