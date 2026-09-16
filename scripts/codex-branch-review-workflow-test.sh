#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/codex-branch-review.yml"
CLAUDE_SKILL="$ROOT_DIR/.claude/skills/review-loop/SKILL.md"

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
    if grep -Fq -- "$unexpected" "$WORKFLOW"; then
        fail "신뢰되지 않은 PR 실행을 허용하는 계약이 있습니다: $unexpected"
    fi
}

assert_contains "  pull_request:"
assert_contains "    types: [opened, synchronize, reopened]"
assert_contains "  workflow_dispatch:"
assert_contains "permissions:"
assert_contains "  contents: write"
assert_contains "  pull-requests: write"
assert_contains "github.event_name == 'pull_request'"
assert_contains "github.event.pull_request.head.repo.full_name == github.repository"
assert_contains "github.event.pull_request.author_association"
assert_contains "uses: actions/checkout@v4"
assert_contains "fetch-depth: 0"
assert_contains "shell: powershell"
assert_contains 'Join-Path $env:GITHUB_WORKSPACE'
assert_contains "'.claude/skills/review-loop/SKILL.md'"
assert_contains 'Test-Path -LiteralPath $skillPath -PathType Leaf'
assert_contains 'Verify GitHub review identity'
assert_contains "gh api user --jq '.login'"
assert_contains 'github.repository_owner'
assert_contains 'claude --model sonnet --effort medium -p'
assert_not_contains 'GH_TOKEN: ${{ github.token }}'
[[ -f "$CLAUDE_SKILL" ]] || fail "저장소의 Claude review-loop 스킬 파일이 없습니다: $CLAUDE_SKILL"
for skill_contract in \
    'bash scripts/pr-contract-test.sh <N>' \
    'gh pr review <N> --approve --body-file <review-report-file>' \
    'gh pr review <N> --request-changes --body-file <review-report-file>' \
    'gh pr review <N> --comment --body-file <review-report-file>' \
    'gh pr merge <N> --squash --delete-branch --auto --repo <owner>/<repo>' \
    'gh pr view <N> --json state,mergedAt,mergeCommit,autoMergeRequest,mergeStateStatus' \
    'autoMergeRequest' \
    '현재 실행 중인 자기 자신의 체크' \
    'state == MERGED' \
    'NEEDS_HUMAN' \
    '최대 3회' \
    'attempt == 3'; do
    grep -Fq -- "$skill_contract" "$CLAUDE_SKILL" \
        || fail "Claude review-loop 스킬에 다음 리뷰·머지 계약이 없습니다: $skill_contract"
done
assert_not_contains "shell: bash"
assert_not_contains "  push:"
assert_not_contains "github.event_name == 'push'"
assert_not_contains "pull_request_target"
assert_not_contains 'Join-Path $env:USERPROFILE'

printf 'Codex branch review workflow contract passed\n'
