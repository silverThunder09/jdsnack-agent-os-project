#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE=""
BRANCH=""
BASE_SHA=""
MAX_ATTEMPTS="${CODEX_PUSH_ATTEMPTS:-3}"
RETRY_DELAY="${CODEX_PUSH_RETRY_DELAY_SECONDS:-5}"
PUBLISH_TMP_ROOT=""
TRUSTED_HOOK_DIR=""
HOOK_CONFIG_REPO=""
ORIGINAL_HOOK_PATH=""
ORIGINAL_HOOK_PATH_SET=false

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

shell_quote() {
    local value="$1"
    value="${value//\'/\'\\\'\'}"
    printf "'%s'" "$value"
}

restore_push_hook() {
    [ -n "$HOOK_CONFIG_REPO" ] || return 0
    if [ "$ORIGINAL_HOOK_PATH_SET" = true ]; then
        git -C "$HOOK_CONFIG_REPO" config --local core.hooksPath "$ORIGINAL_HOOK_PATH"
    else
        git -C "$HOOK_CONFIG_REPO" config --local --unset core.hooksPath >/dev/null 2>&1 || true
    fi
    HOOK_CONFIG_REPO=""
}

cleanup() {
    local exit_code=$?
    if ! restore_push_hook; then
        printf 'codex push failed: could not restore the worktree core.hooksPath\n' >&2
        exit_code=20
    fi
    if [ -n "$PUBLISH_TMP_ROOT" ]; then
        rm -rf -- "$PUBLISH_TMP_ROOT"
    fi
    exit "$exit_code"
}
trap cleanup EXIT HUP INT TERM

prepare_trusted_push_hook() {
    local trusted_bash
    local trusted_review_script
    local trusted_bash_literal
    local trusted_review_literal
    local trusted_hook
    local config_hook_dir

    trusted_bash="$(command -v bash 2>/dev/null || true)"
    [ -n "$trusted_bash" ] || fail "trusted Git Bash is unavailable"
    trusted_review_script="$ROOT_DIR/scripts/pre-push-ai-review.sh"
    [ -f "$trusted_review_script" ] || fail "trusted pre-push reviewer is unavailable"

    PUBLISH_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-publish.XXXXXX")" \
        || fail "could not create trusted push hook directory"
    TRUSTED_HOOK_DIR="$PUBLISH_TMP_ROOT/hooks"
    mkdir "$TRUSTED_HOOK_DIR" || fail "could not create trusted push hook directory"
    chmod 700 "$TRUSTED_HOOK_DIR" || fail "could not secure trusted push hook directory"
    trusted_hook="$TRUSTED_HOOK_DIR/pre-push"
    trusted_bash_literal="$(shell_quote "$trusted_bash")"
    trusted_review_literal="$(shell_quote "$trusted_review_script")"
    {
        printf '%s\n' '#!/bin/sh' 'set -eu'
        printf '%s\n' 'unset GH_TOKEN GITHUB_TOKEN GH_BIN GH_CONFIG_DIR'
        printf '%s\n' 'for variable in $(env | sed -n '\''s/^\(GIT_CONFIG_[A-Za-z0-9_]*\)=.*$/\1/p'\''); do unset "$variable"; done'
        printf 'exec %s %s "$@"\n' "$trusted_bash_literal" "$trusted_review_literal"
    } > "$trusted_hook"
    chmod 700 "$trusted_hook" || fail "could not secure trusted push hook"

    HOOK_CONFIG_REPO="$WORKTREE"
    if ORIGINAL_HOOK_PATH="$(git -C "$WORKTREE" config --local --get core.hooksPath 2>/dev/null)"; then
        ORIGINAL_HOOK_PATH_SET=true
    fi
    config_hook_dir="$TRUSTED_HOOK_DIR"
    if command -v cygpath >/dev/null 2>&1; then
        config_hook_dir="$(cygpath -m "$TRUSTED_HOOK_DIR")"
    fi
    git -C "$WORKTREE" config --local core.hooksPath "$config_hook_dir" \
        || fail "could not install trusted push hook"
    if [ "$(git -C "$WORKTREE" config --local --get core.hooksPath)" != "$config_hook_dir" ]; then
        fail "trusted push hook was not installed"
    fi
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
        local credential_helper='!f() { case "$1" in get) printf "protocol=https\nhost=github.com\nusername=x-access-token\npassword=%s\n" "$GH_TOKEN";; esac; }; f'
        env -u GITHUB_TOKEN \
            git -c "credential.helper=$credential_helper" "$@"
    else
        git "$@"
    fi
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

current_branch="$(git -C "$WORKTREE" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[ "$current_branch" = "$BRANCH" ] || fail "worktree branch does not match publish branch"

if ! git_with_github_auth -C "$WORKTREE" fetch origin main --prune >/dev/null 2>&1; then
    fail "could not refresh origin/main before publishing"
fi

local_sha="$(git -C "$WORKTREE" rev-parse HEAD 2>/dev/null || true)"
[ -n "$local_sha" ] || fail "cannot resolve worktree HEAD"
if [ -n "$BASE_SHA" ] && [ "$local_sha" = "$BASE_SHA" ]; then
    fail "Codex did not create a new commit"
fi

if ! git -C "$WORKTREE" diff --quiet || ! git -C "$WORKTREE" diff --cached --quiet; then
    fail "worktree has uncommitted changes"
fi

if ! git -C "$WORKTREE" merge-base --is-ancestor refs/remotes/origin/main "$local_sha"; then
    fail "origin/main advanced; rebase the branch before publishing"
fi

prepare_trusted_push_hook

last_error=""
attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    push_output=""
    if push_output="$(git_with_github_auth -C "$WORKTREE" push origin "refs/heads/$BRANCH:refs/heads/$BRANCH" 2>&1)"; then
        printf '%s\n' "$push_output" >&2
        remote_payload=""
        if remote_payload="$(git_with_github_auth -C "$WORKTREE" ls-remote --exit-code origin "refs/heads/$BRANCH" 2>&1)"; then
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
