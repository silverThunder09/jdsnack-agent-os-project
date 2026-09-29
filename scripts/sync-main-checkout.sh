#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-}"
REMOTE="${SYNC_MAIN_REMOTE:-origin}"
MAIN_BRANCH="main"

usage() {
    cat <<'USAGE'
Usage: scripts/sync-main-checkout.sh [--repo PATH] [--remote NAME]

Fetches origin/main and fast-forwards a clean primary main checkout.
The script never switches branches, resets commits, or merges local work.
USAGE
}

fail() {
    printf 'main checkout sync failed: %s\n' "$1" >&2
    exit 20
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            REPO_ROOT="$2"
            shift 2
            ;;
        --remote)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            REMOTE="$2"
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

if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi

[ -n "$REPO_ROOT" ] || fail "repository root is unknown"
git -C "$REPO_ROOT" rev-parse --show-toplevel >/dev/null 2>&1 \
    || fail "not a Git repository: $REPO_ROOT"

current_branch="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[ "$current_branch" = "$MAIN_BRANCH" ] \
    || fail "primary checkout must be on $MAIN_BRANCH (currently ${current_branch:-detached})"

worktree_status="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)"
[ -z "$worktree_status" ] \
    || fail "worktree has uncommitted or untracked changes; preserve them and sync manually"

git -C "$REPO_ROOT" fetch "$REMOTE" "$MAIN_BRANCH" --prune \
    || fail "could not fetch $REMOTE/$MAIN_BRANCH"

local_sha="$(git -C "$REPO_ROOT" rev-parse "refs/heads/$MAIN_BRANCH" 2>/dev/null || true)"
remote_sha="$(git -C "$REPO_ROOT" rev-parse "refs/remotes/$REMOTE/$MAIN_BRANCH" 2>/dev/null || true)"
[ -n "$local_sha" ] || fail "local $MAIN_BRANCH ref is unavailable"
[ -n "$remote_sha" ] || fail "$REMOTE/$MAIN_BRANCH ref is unavailable after fetch"

if [ "$local_sha" = "$remote_sha" ]; then
    printf 'main checkout already up to date: %s\n' "$local_sha"
    exit 0
fi

if ! git -C "$REPO_ROOT" merge-base --is-ancestor "$local_sha" "$remote_sha"; then
    if git -C "$REPO_ROOT" merge-base --is-ancestor "$remote_sha" "$local_sha"; then
        fail "local $MAIN_BRANCH is ahead of $REMOTE/$MAIN_BRANCH; do not overwrite local commits"
    fi
    fail "local $MAIN_BRANCH and $REMOTE/$MAIN_BRANCH have diverged; resolve manually"
fi

git -C "$REPO_ROOT" merge --ff-only "$REMOTE/$MAIN_BRANCH" \
    || fail "fast-forward from $REMOTE/$MAIN_BRANCH failed"

final_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
[ "$final_sha" = "$remote_sha" ] \
    || fail "verification failed: HEAD=$final_sha but $REMOTE/$MAIN_BRANCH=$remote_sha"

worktree_status="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)"
[ -z "$worktree_status" ] \
    || fail "worktree became dirty during synchronization"

printf 'main checkout synchronized: %s -> %s\n' "$local_sha" "$final_sha"
