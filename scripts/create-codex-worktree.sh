#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-}"
BRANCH=""
WORKTREE=""
CODEX_WINDOWS_WORKTREE="${CODEX_WINDOWS_WORKTREE:-false}"
TRUSTED_GIT=""
TRUSTED_BASH=""
TRUSTED_PATH=""
TRUSTED_FIND=""
TRUSTED_TOOL_DIRS=()

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

resolve_trusted_tool() {
    local name="$1"
    local directory
    local candidate
    for directory in "${TRUSTED_TOOL_DIRS[@]}"; do
        for candidate in "$directory/$name" "$directory/$name.exe"; do
            if [ -f "$candidate" ] && [ -x "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done
    fail "trusted $name executable is unavailable"
}

trusted_git() (
    local variable
    export PATH="$TRUSTED_PATH"
    unset GITHUB_TOKEN GH_BIN GH_CONFIG_DIR GIT_ASKPASS GIT_SSH GIT_SSH_COMMAND SSH_AUTH_SOCK SSH_AGENT_PID
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy GIT_PROXY_COMMAND
    unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
    unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
        GIT_OBJECT_DIRECTORY_RELATIVE GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE
    unset HOME USERPROFILE XDG_CONFIG_HOME
    for variable in ${!GIT_@}; do
        unset "$variable"
    done
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_SYSTEM=/dev/null
    export GIT_CONFIG_GLOBAL=/dev/null
    export GIT_TERMINAL_PROMPT=0
    "$TRUSTED_GIT" \
        -c credential.helper= \
        -c core.askPass= \
        -c core.sshCommand= \
        -c http.extraheader= \
        "$@"
)

remote_mode_for_repo() {
    local repo="$1"
    local remote_url
    local remote_push_url
    local fetch_mode
    local push_mode
    local fetch_identity=""
    local push_identity=""
    local expected_identity=""
    remote_url="$(trusted_git -C "$repo" remote get-url origin 2>/dev/null || true)"
    remote_push_url="$(trusted_git -C "$repo" remote get-url --push origin 2>/dev/null || true)"
    [ -n "$remote_url" ] && [ -n "$remote_push_url" ] || return 20
    fetch_mode="$(remote_mode_for_url "$remote_url")" || return 20
    push_mode="$(remote_mode_for_url "$remote_push_url")" || return 20
    [ "$fetch_mode" = "$push_mode" ] || return 20
    if [ -n "${GITHUB_REPOSITORY:-}" ]; then
        expected_identity="$(remote_repository_identity "$GITHUB_REPOSITORY")" || return 20
    fi
    case "$fetch_mode" in
        github-*)
            fetch_identity="$(remote_repository_identity "$remote_url")" || return 20
            push_identity="$(remote_repository_identity "$remote_push_url")" || return 20
            [ "$fetch_identity" = "$push_identity" ] || return 20
            [ -z "$expected_identity" ] || [ "$fetch_identity" = "$expected_identity" ] || return 20
            ;;
        *) ;;
    esac
    printf '%s\n' "$fetch_mode"
}

remote_repository_identity() {
    local url="$1"
    local path
    case "$url" in
        https://github.com/*) path="${url#https://github.com/}" ;;
        git@github.com:*) path="${url#git@github.com:}" ;;
        ssh://git@github.com/*) path="${url#ssh://git@github.com/}" ;;
        [A-Za-z0-9._-]*/[A-Za-z0-9._-]*) path="$url" ;;
        *) return 20 ;;
    esac
    path="${path%.git}"
    [[ "$path" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || return 20
    printf '%s\n' "${path,,}"
}

remote_mode_for_url() {
    local url="$1"
    local host
    case "$url" in
        https://*)
            host="${url#https://}"
            host="${host%%/*}"
            [ "$host" = github.com ] || return 20
            printf '%s\n' 'github-https'
            ;;
        git@github.com:*|ssh://git@github.com/*) printf '%s\n' 'github-ssh' ;;
        /*|[A-Za-z]:[\\/]*|file:///*) printf '%s\n' 'local' ;;
        *) return 20 ;;
    esac
}

validate_existing_github_header() {
    local repo="$1"
    local values
    local value
    local count=0
    values="$(trusted_git -C "$repo" config --local --get-all http.https://github.com/.extraheader 2>/dev/null || true)"
    while IFS= read -r value; do
        [ -n "$value" ] || continue
        count=$((count + 1))
    done <<< "$values"
    if [ "$count" -gt 1 ]; then
        printf 'codex worktree creation failed: repository local Git config contains multiple GitHub Authorization headers\n' >&2
        return 20
    fi
}

git_with_github_auth() {
    local auth_repo=""
    local expect_repo=false
    local arg
    local remote_mode
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

    auth_repo="${auth_repo:-.}"
    if ! remote_mode="$(remote_mode_for_repo "$auth_repo")"; then
        return 20
    fi

    local has_existing_header=false
    if [ -n "$auth_repo" ]; then
        if ! validate_existing_github_header "$auth_repo"; then
            return 20
        fi
        if trusted_git -C "$auth_repo" config --local --get-all http.https://github.com/.extraheader >/dev/null 2>&1; then
            has_existing_header=true
        fi
    elif trusted_git config --local --get-all http.https://github.com/.extraheader >/dev/null 2>&1; then
        has_existing_header=true
    fi

    if [ "$remote_mode" = github-https ] && [ -n "${GH_TOKEN:-}" ] && [ "$has_existing_header" = false ]; then
        local credential_helper='!f() { protocol=; host=; while IFS= read -r line; do case "$line" in protocol=*) protocol="${line#protocol=}";; host=*) host="${line#host=}";; "") break;; esac; done; if [ "$protocol" = https ] && [ "$host" = github.com ]; then printf "protocol=https\nhost=github.com\nusername=x-access-token\npassword=%s\n" "$GH_TOKEN"; fi; }; f'
        trusted_git -c "credential.helper=$credential_helper" "$@"
    else
        trusted_git "$@"
    fi
}

reject_untrusted_local_config() {
    local key
    local local_keys
    local_keys="$(trusted_git -C "$1" config --local --name-only --get-regexp \
        '^(url\..*\.(insteadOf|pushInsteadOf)|http\..*|include(If\..*)?\.path)$' 2>/dev/null || true)"
    while IFS= read -r key; do
        [ -z "$key" ] && continue
        case "$key" in
            http.https://github.com/.extraheader) ;;
            *) fail "repository local Git config contains an unsafe remote rewrite or HTTP header: $key" ;;
        esac
    done <<< "$local_keys"
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

TRUSTED_TOOL_DIRS=()
for directory in /usr/bin /bin /mingw64/bin; do
    [ -d "$directory" ] || continue
    TRUSTED_TOOL_DIRS+=("$directory")
done
[ "${#TRUSTED_TOOL_DIRS[@]}" -gt 0 ] || fail "trusted system executable directories are unavailable"
TRUSTED_PATH="$(IFS=:; printf '%s' "${TRUSTED_TOOL_DIRS[*]}")"
TRUSTED_GIT="$(resolve_trusted_tool git)"
TRUSTED_BASH="$(resolve_trusted_tool bash)"
TRUSTED_FIND="$(resolve_trusted_tool find)"

reject_untrusted_local_config "$REPO_ROOT"
if ! remote_mode_for_repo "$REPO_ROOT" >/dev/null; then
    fail "refusing authenticated Git operation for non-GitHub origin"
fi

git_with_github_auth -C "$REPO_ROOT" fetch origin main --prune >&2 || fail "could not fetch origin/main"
trusted_git -C "$REPO_ROOT" show-ref --verify --quiet refs/remotes/origin/main || fail "origin/main is unavailable"

if [ -e "$WORKTREE" ] && [ "$("$TRUSTED_FIND" "$WORKTREE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    fail "worktree path is not empty: $WORKTREE"
fi

if [ "$CODEX_WINDOWS_WORKTREE" = true ]; then
    origin_url="$(trusted_git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
    origin_push_url="$(trusted_git -C "$REPO_ROOT" remote get-url --push origin 2>/dev/null || true)"
    [ -n "$origin_url" ] || fail "origin URL is unavailable"
    trusted_git clone --no-hardlinks --no-checkout "$REPO_ROOT" "$WORKTREE" >&2 || fail "standalone Codex clone failed"
    trusted_git -C "$WORKTREE" remote set-url origin "$origin_url" || fail "could not set standalone clone origin URL"
    if [ -n "$origin_push_url" ]; then
        trusted_git -C "$WORKTREE" remote set-url --push origin "$origin_push_url" || fail "could not set standalone clone push URL"
    fi
    trusted_git -C "$WORKTREE" config --local core.hooksPath .githooks || fail "could not configure standalone clone hooks"
    trusted_git -C "$WORKTREE" config --local jdsnack.hookBash "$TRUSTED_BASH" || fail "could not configure standalone clone hook Bash"
    base_sha="$(trusted_git -C "$REPO_ROOT" rev-parse refs/remotes/origin/main)"
    trusted_git -C "$WORKTREE" update-ref refs/remotes/origin/main "$base_sha" || fail "could not copy origin/main to standalone clone"
    trusted_git -C "$WORKTREE" switch -c "$BRANCH" "$base_sha" >&2 || fail "standalone Codex branch creation failed"
    [ -f "$WORKTREE/.githooks/pre-push" ] || fail "standalone clone is missing the pre-push hook"
else
    trusted_git -C "$REPO_ROOT" worktree add -b "$BRANCH" "$WORKTREE" refs/remotes/origin/main >&2 || fail "git worktree add failed"
fi
printf 'created %s from origin/main at %s\n' "$BRANCH" "$(trusted_git -C "$WORKTREE" rev-parse HEAD)"
