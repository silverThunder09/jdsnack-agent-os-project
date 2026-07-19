#!/usr/bin/env bash
set -euo pipefail

WORKTREE=""
BRANCH=""
BASE_SHA=""
MAX_ATTEMPTS="${CODEX_PUSH_ATTEMPTS:-3}"
RETRY_DELAY="${CODEX_PUSH_RETRY_DELAY_SECONDS:-5}"

usage() {
    cat <<'USAGE'
Usage: scripts/publish-codex-branch.sh --worktree PATH --branch codex/... [--base-sha SHA]

Publishes the worktree HEAD to origin and verifies the remote branch SHA.
Exit codes:
  0  push and remote verification succeeded
  20 push or remote verification failed
  2  invalid command-line arguments
USAGE
}

fail() {
    printf 'codex push failed: %s\n' "$1" >&2
    exit 20
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --worktree)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            WORKTREE="$2"
            shift 2
            ;;
        --branch)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            BRANCH="$2"
            shift 2
            ;;
        --base-sha)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            BASE_SHA="$2"
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

[ -n "$WORKTREE" ] || { usage >&2; exit 2; }
[ -n "$BRANCH" ] || { usage >&2; exit 2; }
[ -d "$WORKTREE" ] || fail "worktree does not exist: $WORKTREE"
case "$MAX_ATTEMPTS" in
    ''|*[!0-9]*|0) fail "CODEX_PUSH_ATTEMPTS must be a positive integer" ;;
esac

local_sha="$(git -C "$WORKTREE" rev-parse HEAD 2>/dev/null || true)"
[ -n "$local_sha" ] || fail "cannot resolve worktree HEAD"
if [ -n "$BASE_SHA" ] && [ "$local_sha" = "$BASE_SHA" ]; then
    fail "Codex did not create a new commit"
fi

last_error=""
attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    push_output=""
    if push_output="$(git -C "$WORKTREE" push origin "$local_sha:refs/heads/$BRANCH" 2>&1)"; then
        printf '%s\n' "$push_output" >&2
        remote_payload=""
        if remote_payload="$(git -C "$WORKTREE" ls-remote --exit-code origin "refs/heads/$BRANCH" 2>&1)"; then
            remote_sha="$(printf '%s\n' "$remote_payload" | awk 'NR == 1 { print $1 }')"
            if [ "$remote_sha" = "$local_sha" ]; then
                printf 'codex push verified: %s -> origin/%s\n' "$local_sha" "$BRANCH"
                exit 0
            fi
            last_error="origin/$BRANCH is ${remote_sha:-unreadable} but worktree HEAD is $local_sha"
        else
            last_error="cannot verify origin/$BRANCH: $remote_payload"
        fi
    else
        printf '%s\n' "$push_output" >&2
        last_error="${push_output:-git push failed}"
    fi

    if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
        printf 'codex push attempt %s/%s failed; retrying in %ss\n' "$attempt" "$MAX_ATTEMPTS" "$RETRY_DELAY" >&2
        sleep "$RETRY_DELAY"
    fi
    attempt=$((attempt + 1))
done

fail "$last_error"
