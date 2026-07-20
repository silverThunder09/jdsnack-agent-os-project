#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
BRANCH=""
WORKTREE=""

usage() {
    cat <<'USAGE'
Usage: scripts/create-codex-worktree.sh --branch codex/... --worktree PATH

Fetches origin/main and creates a new Codex worktree from that exact remote base.
The branch must not already exist.
USAGE
}

fail() {
    printf 'codex worktree creation failed: %s\n' "$1" >&2
    exit 20
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --branch)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            BRANCH="$2"
            shift 2
            ;;
        --worktree)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            WORKTREE="$2"
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

[ -n "$REPO_ROOT" ] || fail "repository root is unknown"
[ -n "$BRANCH" ] || { usage >&2; exit 2; }
[ -n "$WORKTREE" ] || { usage >&2; exit 2; }
case "$BRANCH" in
    codex/*) ;;
    *) fail "branch must use the codex/ prefix" ;;
esac
[ "$WORKTREE" != "$REPO_ROOT" ] || fail "worktree must be separate from the repository root"

git -C "$REPO_ROOT" fetch origin main --prune >&2 || fail "could not fetch origin/main"
git -C "$REPO_ROOT" show-ref --verify --quiet refs/remotes/origin/main || fail "origin/main is unavailable"

if [ -e "$WORKTREE" ] && [ "$(find "$WORKTREE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    fail "worktree path is not empty: $WORKTREE"
fi

git -C "$REPO_ROOT" worktree add -b "$BRANCH" "$WORKTREE" refs/remotes/origin/main >&2 || fail "git worktree add failed"
printf 'created %s from origin/main at %s\n' "$BRANCH" "$(git -C "$WORKTREE" rev-parse HEAD)"
