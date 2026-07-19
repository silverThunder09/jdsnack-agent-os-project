#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPATCHER="$ROOT_DIR/scripts/open-issue-work-dispatcher.sh"
FIXTURE_GH="$ROOT_DIR/scripts/test-fixtures/open-issue-work-dispatcher/gh"

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"
    if [ "$expected" != "$actual" ]; then
        printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$actual" >&2
        exit 1
    fi
}

run_dispatcher() {
    local scenario="$1"
    set +e
    output="$(
        GH_BIN="$FIXTURE_GH" \
        GH_REPO=fixture/repo \
        OPEN_ISSUE_FIXTURE_SCENARIO="$scenario" \
        bash "$DISPATCHER"
    )"
    exit_code=$?
    set -e
}

run_dispatcher safe-empty
assert_eq 0 "$exit_code" "safe empty exit code"
assert_eq no_action "$(printf '%s' "$output" | jq -r .status)" "safe empty status"
assert_eq 0 "$(printf '%s' "$output" | jq '.candidates | length')" "safe empty candidates"
assert_eq 3 "$(printf '%s' "$output" | jq '.skipped | length')" "safe empty skipped issues"

run_dispatcher actionable
assert_eq 10 "$exit_code" "actionable exit code"
assert_eq actionable "$(printf '%s' "$output" | jq -r .status)" "actionable status"
assert_eq codex/example "$(printf '%s' "$output" | jq -r .candidates[0].branch)" "actionable branch"

run_dispatcher malformed
assert_eq 20 "$exit_code" "malformed exit code"
assert_eq needs_human "$(printf '%s' "$output" | jq -r .status)" "malformed status"

set +e
output="$(
    GH_BIN="$FIXTURE_GH" \
    GH_REPO=fixture/repo \
    OPEN_ISSUE_FIXTURE_SCENARIO=safe-empty \
    CODEX_BIN=missing-codex \
    bash "$DISPATCHER" --apply
)"
exit_code=$?
set -e
assert_eq 0 "$exit_code" "apply with no candidates exit code"
assert_eq no_action "$(printf '%s' "$output" | jq -r .status)" "apply with no candidates status"

printf 'Open issue dispatcher tests passed\n'
