#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISH="$ROOT_DIR/scripts/publish-codex-branch.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-publish.XXXXXX")"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"
    if [ "$expected" != "$actual" ]; then
        printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$actual" >&2
        exit 1
    fi
}

git init --bare -q "$TEST_ROOT/remote.git"
git init -q "$TEST_ROOT/work"
git -C "$TEST_ROOT/work" config user.name test
git -C "$TEST_ROOT/work" config user.email test@example.com
printf 'initial\n' > "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm initial
git -C "$TEST_ROOT/work" branch -M codex/example
git -C "$TEST_ROOT/work" remote add origin "$TEST_ROOT/remote.git"
git -C "$TEST_ROOT/work" push -q -u origin codex/example
git -C "$TEST_ROOT/work" push -q origin HEAD:refs/heads/main
base_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"

set +e
no_commit_output="$(CODEX_PUSH_ATTEMPTS=1 "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/example --base-sha "$base_sha" 2>&1)"
no_commit_code=$?
set -e
assert_eq 20 "$no_commit_code" "no commit exit code"
case "$no_commit_output" in
    *"did not create a new commit"*) ;;
    *)
        printf 'FAIL: no commit output (%s)\n' "$no_commit_output" >&2
        exit 1
        ;;
esac

printf 'published change\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm published
mkdir -p "$TEST_ROOT/hooks"
cat > "$TEST_ROOT/hooks/pre-push" <<'EOF'
#!/bin/sh
unset GH_TOKEN GITHUB_TOKEN GH_BIN GH_CONFIG_DIR
for variable in $(env | sed -n 's/^\(GIT_CONFIG_[A-Za-z0-9_]*\)=.*$/\1/p'); do
    unset "$variable"
done
if [ -n "${GIT_AUTH_HOOK_LOG:-}" ]; then
    if env | grep -Eq '^GIT_CONFIG_(COUNT|KEY_[0-9]+|VALUE_[0-9]+|PARAMETERS)=' ||
        [ -n "${GH_TOKEN-}" ] || [ -n "${GITHUB_TOKEN-}" ] ||
        [ -n "${GH_BIN-}" ] || [ -n "${GH_CONFIG_DIR-}" ]; then
        printf 'token-in-hook\n' > "$GIT_AUTH_HOOK_LOG"
        exit 1
    fi
    : > "$GIT_AUTH_HOOK_LOG"
fi
while read -r local_ref local_sha remote_ref remote_sha; do
    case "$local_ref" in
        refs/heads/*) ;;
        *) echo "ERROR: branch push requires a local branch ref: $local_ref" >&2; exit 1 ;;
    esac
done
EOF
chmod +x "$TEST_ROOT/hooks/pre-push"
git -C "$TEST_ROOT/work" config core.hooksPath "$TEST_ROOT/hooks"
output="$(CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/example --base-sha "$base_sha")"
assert_eq 0 "$?" "publish exit code"
case "$output" in
    *"codex push verified"*) ;;
    *)
        printf 'FAIL: publish output (%s)\n' "$output" >&2
        exit 1
        ;;
esac

remote_sha="$(git -C "$TEST_ROOT/work" ls-remote origin refs/heads/codex/example | awk 'NR == 1 { print $1 }')"
local_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"
assert_eq "$local_sha" "$remote_sha" "remote SHA"

git -C "$TEST_ROOT/work" switch -q -c codex/auth
auth_base_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"
printf 'authenticated publish\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'authenticated publish'
mkdir -p "$TEST_ROOT/bin"
real_git="$(command -v git)"
cat > "$TEST_ROOT/bin/git" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$GIT_AUTH_LOG"
case " $* " in
    *" push "*)
        export GIT_CONFIG_COUNT=2
        export GIT_CONFIG_KEY_0='http.https://github.com/.extraheader'
        export GIT_CONFIG_VALUE_0='AUTHORIZATION: bearer fixture-token'
        export GIT_CONFIG_KEY_1='http.https://github.com/.extraheader'
        export GIT_CONFIG_VALUE_1='AUTHORIZATION: bearer fixture-token'
        ;;
esac
exec "$GIT_REAL_BIN" "$@"
EOF
chmod +x "$TEST_ROOT/bin/git"
auth_log="$TEST_ROOT/git-auth.log"
hook_auth_log="$TEST_ROOT/hook-auth.log"
auth_output="$(PATH="$TEST_ROOT/bin:$PATH" GIT_AUTH_LOG="$auth_log" GIT_AUTH_HOOK_LOG="$hook_auth_log" GIT_REAL_BIN="$real_git" GH_TOKEN=fixture-token GH_BIN=fixture-gh GH_CONFIG_DIR=fixture-gh-config CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/auth --base-sha "$auth_base_sha")"
case "$auth_output" in
    *"codex push verified"*) ;;
    *)
        printf 'FAIL: authenticated publish output (%s)\n' "$auth_output" >&2
        exit 1
        ;;
esac
grep -Fq 'credential.helper=!f()' "$auth_log"
if grep -Fq "fixture-token" "$auth_log"; then
    printf 'FAIL: authenticated Git command arguments contained the token\n' >&2
    exit 1
fi
if grep -Fq "token-in-hook" "$hook_auth_log"; then
    printf 'FAIL: authenticated push exposed its token to the pre-push hook\n' >&2
    exit 1
fi

git -C "$TEST_ROOT/work" config http.https://github.com/.extraheader 'AUTHORIZATION: bearer existing-fixture'
existing_header_base_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"
printf 'existing checkout header\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'reuse existing checkout header'
existing_header_log="$TEST_ROOT/existing-header-auth.log"
: > "$existing_header_log"
existing_header_output="$(PATH="$TEST_ROOT/bin:$PATH" GIT_AUTH_LOG="$existing_header_log" GIT_REAL_BIN="$real_git" GH_TOKEN=fixture-token GH_BIN=fixture-gh GH_CONFIG_DIR=fixture-gh-config CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/auth --base-sha "$existing_header_base_sha")"
case "$existing_header_output" in
    *"codex push verified"*) ;;
    *)
        printf 'FAIL: existing-header publish output (%s)\n' "$existing_header_output" >&2
        exit 1
        ;;
esac
if grep -Fq "AUTHORIZATION: bearer fixture-token" "$existing_header_log"; then
    printf 'FAIL: existing checkout header was duplicated\n' >&2
    exit 1
fi

set +e
mismatched_output="$(CODEX_PUSH_ATTEMPTS=1 "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/other 2>&1)"
mismatched_code=$?
set -e
assert_eq 20 "$mismatched_code" "mismatched branch exit code"
case "$mismatched_output" in
    *"worktree branch does not match publish branch"*) ;;
    *) printf 'FAIL: mismatched branch output (%s)\n' "$mismatched_output" >&2; exit 1 ;;
esac
test -z "$(git -C "$TEST_ROOT/work" ls-remote origin refs/heads/codex/other)"

git -C "$TEST_ROOT/work" switch -q -c main
printf 'remote main advanced\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'advance remote main'
git -C "$TEST_ROOT/work" push -q origin main
git -C "$TEST_ROOT/work" switch -q codex/example
printf 'stale feature change\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'stale feature change'

set +e
stale_output="$(CODEX_PUSH_ATTEMPTS=1 "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/example --base-sha "$local_sha" 2>&1)"
stale_code=$?
set -e
assert_eq 20 "$stale_code" "stale base exit code"
case "$stale_output" in
    *"origin/main advanced; rebase the branch before publishing"*) ;;
    *)
        printf 'FAIL: stale base output (%s)\n' "$stale_output" >&2
        exit 1
        ;;
esac

printf 'Codex branch publish tests passed\n'
