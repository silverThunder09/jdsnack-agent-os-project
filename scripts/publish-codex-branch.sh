#!/usr/bin/env bash
set -euo pipefail
umask 077

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
TRUSTED_GIT=""
TRUSTED_ENV=""
TRUSTED_MKDIR=""
TRUSTED_MKTEMP=""
TRUSTED_CHMOD=""
TRUSTED_RM=""
TRUSTED_AWK=""
TRUSTED_SLEEP=""
TRUSTED_SED=""
TRUSTED_CYGPATH=""
TRUSTED_BASH=""
TRUSTED_PATH=""
TRUSTED_STAT=""
TRUSTED_READLINK=""
TRUSTED_ID=""
TRUSTED_CODEX_HOME=""
TRUSTED_HOME=""
TRUSTED_SYSTEM_ROOT=""
TRUSTED_WINDIR=""
TRUSTED_WSL_INTEROP=""
TRUSTED_WSLENV=""
TRUSTED_CODEX_BIN=""
TRUSTED_TOOL_DIRS=()

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

resolve_optional_trusted_tool() {
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
}

validate_trusted_path_ancestors() {
    local path="$1"
    local parent
    local mode
    local owner
    local current_user
    current_user="$("$TRUSTED_ID" -un 2>/dev/null || true)"
    [ -n "$current_user" ] || fail "trusted executable owner cannot be verified"
    while :; do
        [ -e "$path" ] || fail "trusted executable path is unavailable: $path"
        mode="$("$TRUSTED_STAT" -c '%a' -- "$path" 2>/dev/null || true)"
        case "$mode" in
            ''|*[!0-7]*) fail "trusted executable permissions cannot be verified: $path" ;;
        esac
        if (( 8#$mode & 022 )); then
            fail "trusted executable path is group- or world-writable: $path"
        fi
        owner="$("$TRUSTED_STAT" -c '%U' -- "$path" 2>/dev/null || true)"
        case "$owner" in
            root|"$current_user") ;;
            *) fail "trusted executable path has an untrusted owner: $path" ;;
        esac
        parent="$(dirname -- "$path")"
        [ "$parent" != "$path" ] || break
        path="$parent"
    done
}

resolve_trusted_codex_bin() {
    local candidate="${CODEX_BIN:-}"
    local canonical
    local mode
    local owner
    local current_user
    [ -z "$candidate" ] && return 0
    case "$candidate" in
        /*|[A-Za-z]:[\\/]*) ;;
        *) fail "CODEX_BIN must be an absolute trusted executable path" ;;
    esac
    [ -f "$candidate" ] && [ -x "$candidate" ] || fail "CODEX_BIN executable is unavailable"
    canonical="$("$TRUSTED_READLINK" -f -- "$candidate" 2>/dev/null || true)"
    [ -n "$canonical" ] || fail "CODEX_BIN target cannot be resolved"
    [ -f "$canonical" ] && [ -x "$canonical" ] || fail "CODEX_BIN target is unavailable"
    validate_trusted_path_ancestors "$canonical"
    case "$canonical" in
        "$WORKTREE"|"$WORKTREE"/*|"$ROOT_DIR"|"$ROOT_DIR"/*) fail "CODEX_BIN points inside the untrusted checkout" ;;
        /usr/bin/codex*|/bin/codex*|/usr/local/bin/codex*|/mingw64/bin/codex*|/c/Users/*/AppData/Local/OpenAI/Codex/*|/c/Users/*/AppData/Local/Programs/OpenAI/Codex/*|/c/Users/*/.codex/packages/standalone/releases/*/bin/codex*|/mnt/c/Users/*/AppData/Local/OpenAI/Codex/*|/mnt/c/Users/*/AppData/Local/Programs/OpenAI/Codex/*|/mnt/c/Users/*/.codex/packages/standalone/releases/*/bin/codex*) ;;
        *) fail "CODEX_BIN is outside the trusted Codex installation paths" ;;
    esac
    mode="$("$TRUSTED_STAT" -c '%a' -- "$canonical" 2>/dev/null || true)"
    case "$mode" in
        ''|*[!0-7]*) fail "CODEX_BIN permissions cannot be verified" ;;
    esac
    if (( 8#$mode & 022 )); then
        fail "CODEX_BIN is group- or world-writable"
    fi
    owner="$("$TRUSTED_STAT" -c '%U' -- "$canonical" 2>/dev/null || true)"
    current_user="$("$TRUSTED_ID" -un 2>/dev/null || true)"
    [ -n "$owner" ] && [ -n "$current_user" ] || fail "CODEX_BIN owner cannot be verified"
    case "$canonical" in
        /usr/bin/*|/bin/*|/usr/local/bin/*|/mingw64/bin/*)
            case "$owner" in root|"$current_user") ;;
                *) fail "CODEX_BIN system executable has an untrusted owner" ;;
            esac
            ;;
        *)
            [ "$owner" = "$current_user" ] || fail "CODEX_BIN user executable has an untrusted owner"
            ;;
    esac
    printf '%s\n' "$canonical"
}

init_trusted_tools() {
    local directory
    TRUSTED_TOOL_DIRS=()
    for directory in /usr/bin /bin /mingw64/bin; do
        [ -d "$directory" ] || continue
        TRUSTED_TOOL_DIRS+=("$directory")
    done
    [ "${#TRUSTED_TOOL_DIRS[@]}" -gt 0 ] || fail "trusted system executable directories are unavailable"
    TRUSTED_PATH="$(IFS=:; printf '%s' "${TRUSTED_TOOL_DIRS[*]}")"
    TRUSTED_GIT="$(resolve_trusted_tool git)"
    TRUSTED_ENV="$(resolve_trusted_tool env)"
    TRUSTED_MKDIR="$(resolve_trusted_tool mkdir)"
    TRUSTED_MKTEMP="$(resolve_trusted_tool mktemp)"
    TRUSTED_CHMOD="$(resolve_trusted_tool chmod)"
    TRUSTED_RM="$(resolve_trusted_tool rm)"
    TRUSTED_AWK="$(resolve_trusted_tool awk)"
    TRUSTED_SLEEP="$(resolve_trusted_tool sleep)"
    TRUSTED_SED="$(resolve_trusted_tool sed)"
    TRUSTED_CYGPATH="$(resolve_optional_trusted_tool cygpath)"
    TRUSTED_BASH="$(resolve_trusted_tool bash)"
    TRUSTED_STAT="$(resolve_trusted_tool stat)"
    TRUSTED_READLINK="$(resolve_trusted_tool readlink)"
    TRUSTED_ID="$(resolve_trusted_tool id)"
    TRUSTED_CODEX_HOME="$(resolve_trusted_runtime_dir CODEX_HOME "${CODEX_HOME:-}")"
    TRUSTED_HOME="$(resolve_trusted_runtime_dir HOME "${HOME:-}")"
    TRUSTED_SYSTEM_ROOT="$(resolve_trusted_runtime_dir SystemRoot "${SystemRoot:-}")"
    TRUSTED_WINDIR="$(resolve_trusted_runtime_dir WINDIR "${WINDIR:-}")"
    TRUSTED_WSL_INTEROP="${WSL_INTEROP:-}"
    TRUSTED_WSLENV=""
    for directory in \
        "$TRUSTED_SYSTEM_ROOT/System32" \
        "$TRUSTED_SYSTEM_ROOT/System32/WindowsPowerShell/v1.0" \
        "$TRUSTED_WINDIR/System32" \
        "$TRUSTED_WINDIR/System32/WindowsPowerShell/v1.0"; do
        [ -d "$directory" ] || continue
        case ":$TRUSTED_PATH:" in
            *":$directory:"*) ;;
            *) TRUSTED_PATH="$TRUSTED_PATH:$directory" ;;
        esac
    done
    TRUSTED_CODEX_BIN="$(resolve_trusted_codex_bin)"
    case "$TRUSTED_CODEX_BIN" in
        *.exe)
            case "$TRUSTED_CODEX_BIN" in
                /mnt/*|/c/*)
                    [ -n "$TRUSTED_WSL_INTEROP" ] || fail "Windows Codex requires WSL interop"
                    TRUSTED_WSLENV='CODEX_HOME/p:TEMP/p:TMP/p:TMPDIR/p'
                    ;;
            esac
            ;;
    esac
}

resolve_trusted_runtime_dir() {
    local name="$1"
    local value="$2"
    local canonical
    [ -z "$value" ] && return 0
    case "$value" in
        /*|[A-Za-z]:[\\/]*) ;;
        *) fail "$name must be an absolute path" ;;
    esac
    canonical="$(cd -- "$value" 2>/dev/null && pwd -P)" || fail "$name is unavailable"
    case "$canonical" in
        "$WORKTREE"|"$WORKTREE"/*|"$ROOT_DIR"|"$ROOT_DIR"/*) fail "$name points inside the untrusted checkout" ;;
    esac
    printf '%s\n' "$canonical"
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

shell_quote() {
    local value="$1"
    value="${value//\'/\'\\\'\'}"
    printf "'%s'" "$value"
}

restore_push_hook() {
    [ -n "$HOOK_CONFIG_REPO" ] || return 0
    if [ "$ORIGINAL_HOOK_PATH_SET" = true ]; then
        trusted_git -C "$HOOK_CONFIG_REPO" config --local core.hooksPath "$ORIGINAL_HOOK_PATH" || return 20
    else
        trusted_git -C "$HOOK_CONFIG_REPO" config --local --unset core.hooksPath >/dev/null 2>&1 || return 20
    fi
    HOOK_CONFIG_REPO=""
}

cleanup() {
    local exit_code=$?
    trap - EXIT
    if ! restore_push_hook; then
        printf 'codex push failed: could not restore the worktree core.hooksPath\n' >&2
        exit_code=20
    fi
    if [ -n "$PUBLISH_TMP_ROOT" ] && [ -z "$HOOK_CONFIG_REPO" ]; then
        if ! "$TRUSTED_RM" -rf -- "$PUBLISH_TMP_ROOT"; then
            printf 'codex push failed: could not remove trusted hook directory: %s\n' "$PUBLISH_TMP_ROOT" >&2
            exit_code=20
        fi
    elif [ -n "$PUBLISH_TMP_ROOT" ]; then
        printf 'codex push warning: retained trusted hook directory because core.hooksPath restoration failed: %s\n' "$PUBLISH_TMP_ROOT" >&2
    fi
    exit "$exit_code"
}
trap cleanup EXIT

prepare_trusted_push_hook() {
    local trusted_review_script
    local trusted_env_literal
    local trusted_sed_literal
    local trusted_bash_literal
    local trusted_review_literal
    local trusted_hook
    local config_hook_dir

    trusted_review_script="$ROOT_DIR/scripts/pre-push-ai-review.sh"
    [ -f "$trusted_review_script" ] || fail "trusted pre-push reviewer is unavailable"

    "$TRUSTED_MKDIR" -p "$ROOT_DIR/.agent-os/runtime" \
        || fail "could not create trusted publish runtime directory"
    PUBLISH_TMP_ROOT="$("$TRUSTED_MKTEMP" -d "$ROOT_DIR/.agent-os/runtime/publish.XXXXXX")" \
        || fail "could not create trusted push hook directory"
    TRUSTED_HOOK_DIR="$PUBLISH_TMP_ROOT/hooks"
    "$TRUSTED_MKDIR" "$TRUSTED_HOOK_DIR" || fail "could not create trusted push hook directory"
    "$TRUSTED_CHMOD" 700 "$TRUSTED_HOOK_DIR" || fail "could not secure trusted push hook directory"
    trusted_hook="$TRUSTED_HOOK_DIR/pre-push"
    trusted_env_literal="$(shell_quote "$TRUSTED_ENV")"
    trusted_sed_literal="$(shell_quote "$TRUSTED_SED")"
    trusted_bash_literal="$(shell_quote "$TRUSTED_BASH")"
    trusted_review_literal="$(shell_quote "$trusted_review_script")"
    runtime_assignments="PATH=$(shell_quote "$TRUSTED_PATH") JDSNACK_REVIEW_BASE_REF=origin/main"
    if [ -n "$TRUSTED_CODEX_HOME" ]; then
        runtime_assignments="$runtime_assignments CODEX_HOME=$(shell_quote "$TRUSTED_CODEX_HOME")"
    fi
    if [ -n "$TRUSTED_HOME" ]; then
        runtime_assignments="$runtime_assignments HOME=$(shell_quote "$TRUSTED_HOME")"
    fi
    if [ -n "$TRUSTED_SYSTEM_ROOT" ]; then
        runtime_assignments="$runtime_assignments SystemRoot=$(shell_quote "$TRUSTED_SYSTEM_ROOT")"
    fi
    if [ -n "$TRUSTED_WINDIR" ]; then
        runtime_assignments="$runtime_assignments WINDIR=$(shell_quote "$TRUSTED_WINDIR")"
    fi
    if [ -n "$TRUSTED_WSL_INTEROP" ]; then
        runtime_assignments="$runtime_assignments WSL_INTEROP=$(shell_quote "$TRUSTED_WSL_INTEROP") WSLENV=$(shell_quote "$TRUSTED_WSLENV")"
    fi
    if [ -n "$TRUSTED_CODEX_BIN" ]; then
        runtime_assignments="$runtime_assignments CODEX_BIN=$(shell_quote "$TRUSTED_CODEX_BIN")"
    fi
    {
        printf '%s\n' '#!/bin/sh' 'set -eu'
        printf '%s\n' 'unset GH_TOKEN GITHUB_TOKEN GH_BIN GH_CONFIG_DIR'
        printf 'for variable in $(%s | %s -n '\''s/^\\(GIT_CONFIG_[A-Za-z0-9_]*\\)=.*$/\\1/p'\''); do unset "$variable"; done\n' \
            "$trusted_env_literal" "$trusted_sed_literal"
        printf 'exec %s -i %s %s %s "$@"\n' \
            "$trusted_env_literal" "$runtime_assignments" "$trusted_bash_literal" "$trusted_review_literal"
    } > "$trusted_hook"
    "$TRUSTED_CHMOD" 700 "$trusted_hook" || fail "could not secure trusted push hook"

    HOOK_CONFIG_REPO="$WORKTREE"
    if ORIGINAL_HOOK_PATH="$(trusted_git -C "$WORKTREE" config --local --get core.hooksPath 2>/dev/null)"; then
        ORIGINAL_HOOK_PATH_SET=true
    fi
    config_hook_dir="$TRUSTED_HOOK_DIR"
    if [ -n "$TRUSTED_CYGPATH" ]; then
        config_hook_dir="$("$TRUSTED_CYGPATH" -m "$TRUSTED_HOOK_DIR")"
    fi
    trusted_git -C "$WORKTREE" config --local core.hooksPath "$config_hook_dir" \
        || fail "could not install trusted push hook"
    if [ "$(trusted_git -C "$WORKTREE" config --local --get core.hooksPath)" != "$config_hook_dir" ]; then
        fail "trusted push hook was not installed"
    fi
}

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
        printf 'codex push failed: repository local Git config contains multiple GitHub Authorization headers\n' >&2
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
    local_keys="$(trusted_git -C "$WORKTREE" config --local --name-only --get-regexp \
        '^(url\..*\.(insteadOf|pushInsteadOf)|http\..*|include(If\..*)?\.path)$' 2>/dev/null || true)"
    while IFS= read -r key; do
        [ -z "$key" ] && continue
        case "$key" in
            http.https://github.com/.extraheader) ;;
            *) fail "worktree local Git config contains an unsafe remote rewrite or HTTP header: $key" ;;
        esac
    done <<< "$local_keys"
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
WORKTREE="$(cd -- "$WORKTREE" && pwd -P)"
init_trusted_tools
reject_untrusted_local_config
if ! remote_mode_for_repo "$WORKTREE" >/dev/null; then
    fail "refusing authenticated Git operation for non-GitHub origin"
fi
case "$MAX_ATTEMPTS" in
    ''|*[!0-9]*|0) fail "CODEX_PUSH_ATTEMPTS must be a positive integer" ;;
esac

current_branch="$(trusted_git -C "$WORKTREE" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[ "$current_branch" = "$BRANCH" ] || fail "worktree branch does not match publish branch"

if ! git_with_github_auth -C "$WORKTREE" fetch origin main --prune >/dev/null 2>&1; then
    fail "could not refresh origin/main before publishing"
fi

local_sha="$(trusted_git -C "$WORKTREE" rev-parse HEAD 2>/dev/null || true)"
[ -n "$local_sha" ] || fail "cannot resolve worktree HEAD"
if [ -n "$BASE_SHA" ] && [ "$local_sha" = "$BASE_SHA" ]; then
    fail "Codex did not create a new commit"
fi

if ! trusted_git -C "$WORKTREE" diff --quiet || ! trusted_git -C "$WORKTREE" diff --cached --quiet; then
    fail "worktree has uncommitted changes"
fi

if ! trusted_git -C "$WORKTREE" merge-base --is-ancestor refs/remotes/origin/main "$local_sha"; then
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
            remote_sha="$(printf '%s\n' "$remote_payload" | "$TRUSTED_AWK" 'NR == 1 { print $1 }')"
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
        "$TRUSTED_SLEEP" "$RETRY_DELAY"
    fi
    attempt=$((attempt + 1))
done

fail "$last_error"
