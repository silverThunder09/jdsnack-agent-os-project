#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTOR="$ROOT_DIR/scripts/pr-feedback-detector.sh"
FIXTURE_GH="$ROOT_DIR/scripts/test-fixtures/pr-feedback-detector/gh"

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"
    if [ "$expected" != "$actual" ]; then
        printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$actual" >&2
        exit 1
    fi
}

run_detector() {
    local scenario="$1"
    local branch="${2:-codex/example}"
    set +e
    output="$(
        GH_BIN="$FIXTURE_GH" \
        GH_REPO=fixture/repo \
        PR_FEEDBACK_FIXTURE_SCENARIO="$scenario" \
        bash "$DETECTOR" --branch "$branch"
    )"
    exit_code=$?
    set -e
}

run_detector no_action
assert_eq 0 "$exit_code" "no-action exit code"
assert_eq no_action "$(printf '%s' "$output" | jq -r .status)" "no-action status"

run_detector issue_rejection
assert_eq 10 "$exit_code" "issue rejection exit code"
assert_eq actionable "$(printf '%s' "$output" | jq -r .status)" "issue rejection status"
assert_eq review_rejection_issue "$(printf '%s' "$output" | jq -r .event_type)" "issue rejection event"
assert_eq 110 "$(printf '%s' "$output" | jq -r .issue.number)" "issue number"

run_detector pr_review
assert_eq 10 "$exit_code" "review rejection exit code"
assert_eq review_changes_requested "$(printf '%s' "$output" | jq -r .event_type)" "review rejection event"

run_detector ci_failure
assert_eq 10 "$exit_code" "CI failure exit code"
assert_eq ci_failed "$(printf '%s' "$output" | jq -r .event_type)" "CI failure event"
assert_eq backend "$(printf '%s' "$output" | jq -r .failed_checks[0].name)" "failed check name"

run_detector ci_error
assert_eq 10 "$exit_code" "CI ERROR exit code"
assert_eq ci_failed "$(printf '%s' "$output" | jq -r .event_type)" "CI ERROR event"

run_detector ci_status_matrix
assert_eq 10 "$exit_code" "CI status matrix exit code"
assert_eq 6 "$(printf '%s' "$output" | jq '.failed_checks | length')" "CI status matrix failed checks"

run_detector ci_optional
assert_eq 0 "$exit_code" "optional check exit code"
assert_eq no_action "$(printf '%s' "$output" | jq -r .status)" "optional check status"

run_detector diff_over_limit
assert_eq 10 "$exit_code" "diff over limit exit code"
assert_eq diff_over_limit "$(printf '%s' "$output" | jq -r .event_type)" "diff over limit event"

set +e
output="$(
    GH_BIN="$FIXTURE_GH" \
    GH_REPO=fixture/repo \
    PR_DIFF_LIMIT=not-a-number \
    bash "$DETECTOR" --branch codex/example
)"
exit_code=$?
set -e
assert_eq 20 "$exit_code" "invalid diff limit exit code"
assert_eq needs_human "$(printf '%s' "$output" | jq -r .status)" "invalid diff limit status"

set +e
bash "$DETECTOR" --branch codex/example --diff-limit not-a-number >/dev/null 2>&1
exit_code=$?
set -e
assert_eq 2 "$exit_code" "invalid CLI diff limit exit code"

run_detector required_checks_unavailable
assert_eq 20 "$exit_code" "required check lookup exit code"
assert_eq needs_human "$(printf '%s' "$output" | jq -r .status)" "required check lookup status"

set +e
output="$(
    GH_BIN="$FIXTURE_GH" \
    GH_REPO=fixture/repo \
    PR_FEEDBACK_FIXTURE_SCENARIO=required_checks_unavailable \
    PR_FEEDBACK_REQUIRED_CHECKS=backend \
    bash "$DETECTOR" --branch codex/example
)"
exit_code=$?
set -e
assert_eq 10 "$exit_code" "required check override exit code"
assert_eq ci_failed "$(printf '%s' "$output" | jq -r .event_type)" "required check override event"

run_detector issue_priority
assert_eq 10 "$exit_code" "rejection issue priority exit code"
assert_eq review_rejection_issue "$(printf '%s' "$output" | jq -r .event_type)" "rejection issue priority event"

run_detector malformed
assert_eq 20 "$exit_code" "malformed GitHub response exit code"
assert_eq needs_human "$(printf '%s' "$output" | jq -r .status)" "malformed GitHub response status"

run_detector invalid_shape
assert_eq 20 "$exit_code" "invalid GitHub response shape exit code"
assert_eq needs_human "$(printf '%s' "$output" | jq -r .status)" "invalid GitHub response shape status"

run_detector invalid_pr_shape
assert_eq 20 "$exit_code" "invalid PR response shape exit code"
assert_eq needs_human "$(printf '%s' "$output" | jq -r .status)" "invalid PR response shape status"

run_detector invalid_required_shape
assert_eq 20 "$exit_code" "invalid required checks response shape exit code"
assert_eq needs_human "$(printf '%s' "$output" | jq -r .status)" "invalid required checks response shape status"

set +e
output="$(
    GH_BIN="$FIXTURE_GH" \
    JQ_BIN=missing-jq \
    GH_REPO=fixture/repo \
    bash "$DETECTOR" --branch codex/example
)"
exit_code=$?
set -e
assert_eq 20 "$exit_code" "jq unavailable exit code"
assert_eq needs_human "$(printf '%s' "$output" | jq -r .status)" "jq unavailable status"

run_detector no_action feature/not-codex
assert_eq 0 "$exit_code" "non-Codex branch exit code"
assert_eq no_action "$(printf '%s' "$output" | jq -r .status)" "non-Codex branch status"

printf 'PR feedback detector tests passed\n'
