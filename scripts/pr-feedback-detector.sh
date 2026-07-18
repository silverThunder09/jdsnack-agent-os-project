#!/usr/bin/env bash
set -euo pipefail

readonly ACTIONABLE_EXIT=10
readonly NEEDS_HUMAN_EXIT=20
readonly DEFAULT_DIFF_LIMIT=1000

GH_BIN="${GH_BIN:-gh}"
JQ_BIN="${JQ_BIN:-jq}"
REPO="${GH_REPO:-}"
BRANCH="${PR_FEEDBACK_BRANCH:-}"
DIFF_LIMIT="${PR_DIFF_LIMIT:-$DEFAULT_DIFF_LIMIT}"

usage() {
    cat <<'USAGE'
Usage: scripts/pr-feedback-detector.sh [--repo OWNER/REPO] [--branch codex/...] [--diff-limit N]

Checks one time for actionable feedback on a Codex branch.
Exit codes:
  0  no actionable feedback
  10 actionable PR/CI/review feedback found
  20 detector cannot determine state and needs a human
USAGE
}

emit_no_action() {
    "$JQ_BIN" -n \
        --arg branch "$BRANCH" \
        --arg repo "$REPO" \
        '{status: "no_action", branch: $branch, repository: $repo, event_key: null}'
    exit 0
}

emit_needs_human() {
    local reason="$1"
    local details="${2:-}"
    "$JQ_BIN" -n \
        --arg branch "$BRANCH" \
        --arg repo "$REPO" \
        --arg reason "$reason" \
        --arg details "$details" \
        '{status: "needs_human", branch: $branch, repository: $repo, reason: $reason, details: $details}'
    exit "$NEEDS_HUMAN_EXIT"
}

emit_actionable() {
    local event_type="$1"
    local event_key="$2"
    local reason="$3"
    local prompt="$4"
    local failed_checks="$5"
    local pr_ref="$6"
    local issue_ref="$7"

    "$JQ_BIN" -n \
        --arg status "actionable" \
        --arg branch "$BRANCH" \
        --arg repo "$REPO" \
        --arg event_type "$event_type" \
        --arg event_key "$event_key" \
        --arg reason "$reason" \
        --arg prompt "$prompt" \
        --argjson failed_checks "$failed_checks" \
        --argjson pr "$pr_ref" \
        --argjson issue "$issue_ref" \
        '{
          status: $status,
          branch: $branch,
          repository: $repo,
          event_type: $event_type,
          event_key: $event_key,
          reason: $reason,
          prompt: $prompt,
          failed_checks: $failed_checks,
          pr: $pr,
          issue: $issue
        }'
    exit "$ACTIONABLE_EXIT"
}

run_gh_json() {
    local output
    if ! output="$($GH_BIN "$@" 2>&1)"; then
        emit_needs_human "github_query_failed" "$output"
    fi
    printf '%s' "$output"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            REPO="$2"
            shift 2
            ;;
        --branch)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            BRANCH="$2"
            shift 2
            ;;
        --diff-limit)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            DIFF_LIMIT="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

command -v "$GH_BIN" >/dev/null 2>&1 || emit_needs_human "gh_unavailable"
command -v "$JQ_BIN" >/dev/null 2>&1 || emit_needs_human "jq_unavailable"

if [ -z "$REPO" ]; then
    repo_payload="$(run_gh_json repo view --json nameWithOwner)"
    REPO="$($JQ_BIN -r '.nameWithOwner // empty' <<EOF
$repo_payload
EOF
)"
    [ -n "$REPO" ] || emit_needs_human "repository_unknown"
fi

if [ -z "$BRANCH" ]; then
    BRANCH="$(git branch --show-current 2>/dev/null || true)"
fi

case "$BRANCH" in
    codex/*) ;;
    *) emit_no_action ;;
esac

pr_list="$(run_gh_json pr list --repo "$REPO" --head "$BRANCH" --state open --json number --limit 1)"
pr_number="$($JQ_BIN -r '.[0].number // empty' <<EOF
$pr_list
EOF
)"
pr_payload="null"
if [ -n "$pr_number" ]; then
    pr_payload="$(run_gh_json pr view "$pr_number" --repo "$REPO" --json number,title,url,state,headRefName,baseRefName,headRefOid,reviewDecision,additions,deletions,changedFiles,statusCheckRollup)"
fi

issue_list="$(run_gh_json issue list --repo "$REPO" --state open --json number,title,url,updatedAt --limit 100)"
issue_number="$($JQ_BIN -r --arg title "리뷰 반려: $BRANCH" 'map(select(.title == $title)) | sort_by(.updatedAt) | last | .number // empty' <<EOF
$issue_list
EOF
)"
issue_payload="null"
if [ -n "$issue_number" ]; then
    issue_payload="$(run_gh_json issue view "$issue_number" --repo "$REPO" --json number,title,url,body,comments,updatedAt)"
fi

pr_ref="$($JQ_BIN -c 'if . == null then null else {
    number, title, url, state, headRefName, baseRefName, headRefOid,
    reviewDecision, additions, deletions, changedFiles
} end' <<EOF
$pr_payload
EOF
)"
issue_ref="$($JQ_BIN -c 'if . == null then null else {
    number, title, url, updatedAt,
    latestComment: (if ((.comments // []) | length) == 0 then null else ((.comments // []) | sort_by(.createdAt) | last | {author: .author.login, createdAt, body}) end)
} end' <<EOF
$issue_payload
EOF
)"

failed_checks="$($JQ_BIN -c 'if . == null then [] else [.statusCheckRollup[]? | select(
    ((.conclusion // .state // "") | ascii_upcase)
    | IN("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE")
  ) | {name, conclusion: (.conclusion // .state), detailsUrl}] end' <<EOF
$pr_payload
EOF
)"

pr_diff_total="$($JQ_BIN -r 'if . == null then 0 else ((.additions // 0) + (.deletions // 0)) end' <<EOF
$pr_payload
EOF
)"
pr_review_decision="$($JQ_BIN -r '.reviewDecision // empty' <<EOF
$pr_payload
EOF
)"
issue_body="$($JQ_BIN -r '.body // empty' <<EOF
$issue_payload
EOF
)"
issue_updated_at="$($JQ_BIN -r '.updatedAt // empty' <<EOF
$issue_payload
EOF
)"
feedback_summary="$(printf '%s' "$issue_body" | tr '\n' ' ' | cut -c 1-500)"
head_oid="$($JQ_BIN -r '.headRefOid // "no-pr"' <<EOF
$pr_payload
EOF
)"

if [ -n "$issue_number" ]; then
    event_key="issue:${issue_number}:${issue_updated_at}"
    emit_actionable \
        "review_rejection_issue" \
        "$event_key" \
        "${feedback_summary:-리뷰 반려 Issue가 열려 있습니다.}" \
        "Read Issue #${issue_number} for branch ${BRANCH}, fix the requested changes on the same branch, run the relevant tests, commit, and push. Preserve business coverage and do not weaken assertions." \
        "$failed_checks" \
        "$pr_ref" \
        "$issue_ref"
fi

if [ "$pr_review_decision" = "CHANGES_REQUESTED" ]; then
    event_key="pr:${pr_number}:${head_oid}:changes-requested"
    emit_actionable \
        "review_changes_requested" \
        "$event_key" \
        "PR #${pr_number} has requested changes." \
        "Read the latest PR review, fix the requested changes on the same branch, run the relevant tests, commit, and push. Preserve business coverage and do not weaken assertions." \
        "$failed_checks" \
        "$pr_ref" \
        "$issue_ref"
fi

if [ "$($JQ_BIN 'length' <<EOF
$failed_checks
EOF
)" -gt 0 ]; then
    event_key="pr:${pr_number}:${head_oid}:checks-failed"
    emit_actionable \
        "ci_failed" \
        "$event_key" \
        "PR #${pr_number} has failed required checks." \
        "Read the failed CI logs, reproduce the failure locally, fix it on the same branch, run the relevant tests, commit, and push." \
        "$failed_checks" \
        "$pr_ref" \
        "$issue_ref"
fi

if [ "$pr_diff_total" -gt "$DIFF_LIMIT" ]; then
    event_key="pr:${pr_number}:${head_oid}:diff-over-limit:${pr_diff_total}"
    emit_actionable \
        "diff_over_limit" \
        "$event_key" \
        "PR #${pr_number} changes ${pr_diff_total} lines, over the ${DIFF_LIMIT}-line limit." \
        "Rebase the branch onto the current base and split unrelated concerns into reviewable branches or PRs. Preserve the requested feature and tests, then push the corrected branch." \
        "$failed_checks" \
        "$pr_ref" \
        "$issue_ref"
fi

emit_no_action
