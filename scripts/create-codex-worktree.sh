#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
BRANCH=""
WORKTREE=""
CODEX_WINDOWS_WORKTREE="${CODEX_WINDOWS_WORKTREE:-false}"

usage() {
    cat <<'USAGE'
Usage: scripts/create-codex-worktree.sh --branch codex/...|automation/spec-... --worktree PATH

Fetches origin/main and creates a new Codex worktree from that exact remote base.
The branch must not already exist. Windows Codex uses a standalone clone so its
Git metadata remains readable outside WSL.
USAGE
}

fail() {
    printf 'codex worktree creation failed: %s\n' "$1" >&2
    exit 20
}

git_with_github_auth() {
    local auth_repo=""
    local expect_repo=false
    local arg
    for arg in "$@"; do
        if [ "$expect_repo" = true ]; then
            auth_repo="$arg"
            break
        fi
        case "$arg" in
            -C)
                expect_repo=true
                ;;
            -C*)
                auth_repo="${arg#-C}"
                break
                ;;
        esac
    done

    local has_existing_header=false
    if [ -n "$auth_repo" ]; then
        if git -C "$auth_repo" config --local --get-all http.extraheader >/dev/null 2>&1 \
            || git -C "$auth_repo" config --local --get-all http.https://github.com/.extraheader >/dev/null 2>&1; then
            has_existing_header=true
        fi
    elif git config --local --get-all http.extraheader >/dev/null 2>&1 \
        || git config --local --get-all http.https://github.com/.extraheader >/dev/null 2>&1; then
        has_existing_header=true
    fi

    if [ -n "${GH_TOKEN:-}" ] && [ "$has_existing_header" = false ]; then
        GIT_CONFIG_COUNT=1 \
        GIT_CONFIG_KEY_0='http.https://github.com/.extraheader' \
        GIT_CONFIG_VALUE_0="AUTHORIZATION: bearer $GH_TOKEN" \
        git "$@"
    else
        git "$@"
    fi
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
    codex/*|automation/spec-*) ;;
    *) fail "branch must use the codex/ or automation/spec- prefix" ;;
esac
[ "$WORKTREE" != "$REPO_ROOT" ] || fail "worktree must be separate from the repository root"

git_with_github_auth -C "$REPO_ROOT" fetch origin main --prune >&2 || fail "could not fetch origin/main"
git -C "$REPO_ROOT" show-ref --verify --quiet refs/remotes/origin/main || fail "origin/main is unavailable"

if [ -e "$WORKTREE" ] && [ "$(find "$WORKTREE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    fail "worktree path is not empty: $WORKTREE"
fi

if [ "$CODEX_WINDOWS_WORKTREE" = true ]; then
    origin_url="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
    origin_push_url="$(git -C "$REPO_ROOT" remote get-url --push origin 2>/dev/null || true)"
    [ -n "$origin_url" ] || fail "origin URL is unavailable"
    git clone --no-hardlinks --no-checkout "$REPO_ROOT" "$WORKTREE" >&2 || fail "standalone Codex clone failed"
    git -C "$WORKTREE" remote set-url origin "$origin_url" || fail "could not set standalone clone origin URL"
    if [ -n "$origin_push_url" ]; then
        git -C "$WORKTREE" remote set-url --push origin "$origin_push_url" || fail "could not set standalone clone push URL"
    fi
    hook_bash_path="$(command -v bash 2>/dev/null || true)"
    [ -n "$hook_bash_path" ] || fail "Git Bash is unavailable for the standalone clone hook"
    git -C "$WORKTREE" config --local core.hooksPath .githooks || fail "could not configure standalone clone hooks"
    git -C "$WORKTREE" config --local jdsnack.hookBash "$hook_bash_path" || fail "could not configure standalone clone hook Bash"
    base_sha="$(git -C "$REPO_ROOT" rev-parse refs/remotes/origin/main)"
    git -C "$WORKTREE" update-ref refs/remotes/origin/main "$base_sha" || fail "could not copy origin/main to standalone clone"
    git -C "$WORKTREE" switch -c "$BRANCH" "$base_sha" >&2 || fail "standalone Codex branch creation failed"
    [ -f "$WORKTREE/.githooks/pre-push" ] || fail "standalone clone is missing the pre-push hook"
else
    git -C "$REPO_ROOT" worktree add -b "$BRANCH" "$WORKTREE" refs/remotes/origin/main >&2 || fail "git worktree add failed"
fi
printf 'created %s from origin/main at %s\n' "$BRANCH" "$(git -C "$WORKTREE" rev-parse HEAD)"
