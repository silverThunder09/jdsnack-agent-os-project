#!/usr/bin/env bash
set -euo pipefail

readonly ACTIONABLE_EXIT=10
readonly NEEDS_HUMAN_EXIT=20

GH_BIN="${GH_BIN:-gh}"
JQ_BIN="${JQ_BIN:-jq}"
CODEX_BIN="${CODEX_BIN:-codex}"
REPO="${GH_REPO:-}"
APPLY=false

usage() {
    cat <<'USAGE'
Usage: scripts/open-issue-work-dispatcher.sh [--repo OWNER/REPO] [--apply]

Scans open issues once and emits safe Codex work candidates as JSON.
With --apply, each safe candidate is handed to Codex in an isolated worktree.
Exit codes:
  0  no safe issue candidate
  10 one or more safe issue candidates found
  20 GitHub state cannot be determined and needs a human
  2  invalid command-line arguments
USAGE
}

emit_needs_human() {
    local reason="$1"
    local details="${2:-}"
    "$JQ_BIN" -n \
        --arg repo "$REPO" \
        --arg reason "$reason" \
        --arg details "$details" \
        '{status: "needs_human", repository: $repo, reason: $reason, details: $details, candidates: [], skipped: []}'
    exit "$NEEDS_HUMAN_EXIT"
}

run_gh_json() {
    local output
    if ! output="$($GH_BIN "$@")"; then
        return 1
    fi
    printf '%s' "$output"
}

validate_json() {
    local payload="$1"
    if ! printf '%s' "$payload" | "$JQ_BIN" -e 'type == "array" and all(.[]; (.number | type) == "number" and (.title | type) == "string" and ((.body == null) or ((.body | type) == "string")) and (.labels | type) == "array" and all(.labels[]; (.name | type) == "string"))' >/dev/null 2>&1; then
        emit_needs_human "github_response_invalid" "open issue list returned an unexpected shape"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            REPO="$2"
            shift 2
            ;;
        --apply)
            APPLY=true
            shift
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
    if ! repo_payload="$(run_gh_json repo view --json nameWithOwner)"; then
        emit_needs_human "github_query_failed" "repo view failed"
    fi
    if ! printf '%s' "$repo_payload" | "$JQ_BIN" -e '(.nameWithOwner | type) == "string" and (.nameWithOwner | length) > 0' >/dev/null 2>&1; then
        emit_needs_human "github_response_invalid" "repo view returned an unexpected shape"
    fi
    REPO="$($JQ_BIN -r '.nameWithOwner' <<EOF
$repo_payload
EOF
)"
fi

if ! issue_payload="$(run_gh_json issue list --repo "$REPO" --state open --json number,title,url,body,labels,updatedAt --limit 100)"; then
    emit_needs_human "github_query_failed" "open issue list failed"
fi
validate_json "$issue_payload"

result="$($JQ_BIN -c --arg repo "$REPO" '
  reduce .[] as $issue (
    {candidates: [], skipped: []};
    ($issue.labels | map(.name)) as $labels |
    (if ($issue.title | test("^리뷰 반려: codex/")) then ($issue.title | capture("^리뷰 반려: (?<branch>codex/[^ ]+)$").branch) else "" end) as $branch |
    if ($branch == "") then
      .skipped += [{number: $issue.number, title: $issue.title, reason: "unsupported_issue_type"}]
    elif ($labels | index("needs-human")) != null then
      .skipped += [{number: $issue.number, title: $issue.title, branch: $branch, reason: "needs_human_label"}]
    elif (($issue.body // "") | test("이미 main에|중복 작업|중복 브랜치|폐기")) then
      .skipped += [{number: $issue.number, title: $issue.title, branch: $branch, reason: "stale_or_duplicate"}]
    else
      .candidates += [{
        number: $issue.number,
        title: $issue.title,
        url: $issue.url,
        branch: $branch,
        updatedAt: $issue.updatedAt,
        prompt: ("Read Issue #" + ($issue.number | tostring) + " for branch " + $branch + ", fix the requested changes on the same branch, run the relevant tests, commit, and push. Preserve business coverage and do not weaken assertions.")
      }]
    end
  ) |
  .status = (if (.candidates | length) > 0 then "actionable" else "no_action" end) |
  .repository = $repo |
  {status, repository, candidates, skipped}
' <<EOF
$issue_payload
EOF
)"

printf '%s\n' "$result"
if [ "$(printf '%s' "$result" | "$JQ_BIN" -r '.status')" != "actionable" ]; then
    exit 0
fi

if [ "$APPLY" = true ]; then
    command -v "$CODEX_BIN" >/dev/null 2>&1 || emit_needs_human "codex_unavailable" "--apply requires the Codex CLI"

    while IFS= read -r candidate; do
        issue_number="$($JQ_BIN -r '.number' <<EOF
$candidate
EOF
)"
        branch="$($JQ_BIN -r '.branch' <<EOF
$candidate
EOF
)"
        prompt="$($JQ_BIN -r '.prompt' <<EOF
$candidate
EOF
)"
        worktree="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-issue-${issue_number}.XXXXXX")"
        cleanup_worktree() {
            git worktree remove --force "$worktree" >/dev/null 2>&1 || true
        }
        trap cleanup_worktree EXIT

        git fetch origin "$branch" >&2
        git worktree add --detach "$worktree" "origin/$branch" >&2
        "$CODEX_BIN" exec \
            --cd "$worktree" \
            --sandbox workspace-write \
            "$prompt Issue URL: $(printf '%s' "$candidate" | "$JQ_BIN" -r '.url'). Work only in this isolated worktree. Commit and push to the existing remote branch $branch. Do not create or merge a PR." >&2

        cleanup_worktree
        trap - EXIT
    done < <($JQ_BIN -c '.candidates[]' <<EOF
$result
EOF
)
fi

if [ "$APPLY" = true ]; then
    exit 0
fi
if [ "$(printf '%s' "$result" | "$JQ_BIN" -r '.status')" = "actionable" ]; then
    exit "$ACTIONABLE_EXIT"
fi
exit 0
