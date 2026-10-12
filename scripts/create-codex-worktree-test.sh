#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREATE="$ROOT_DIR/scripts/create-codex-worktree.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-worktree.XXXXXX")"
checkout_hook_log="$TEST_ROOT/checkout-hook.log"
commit_hook_log="$TEST_ROOT/commit-hook.log"

cleanup() {
    git -C "$TEST_ROOT/work" worktree remove --force "$TEST_ROOT/feature" >/dev/null 2>&1 || true
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

git init --bare -q "$TEST_ROOT/remote.git"
git init -q "$TEST_ROOT/work"
git -C "$TEST_ROOT/work" config user.name test
git -C "$TEST_ROOT/work" config user.email test@example.com
mkdir -p "$TEST_ROOT/work/.githooks"
printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/work/.githooks/pre-push"
chmod +x "$TEST_ROOT/work/.githooks/pre-push"
cat > "$TEST_ROOT/work/.githooks/post-checkout" <<EOF
#!/bin/sh
: > '$checkout_hook_log'
EOF
chmod +x "$TEST_ROOT/work/.githooks/post-checkout"
printf 'initial\n' > "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add .githooks/pre-push
git -C "$TEST_ROOT/work" add .githooks/post-checkout
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm initial
git -C "$TEST_ROOT/work" branch -M main
git -C "$TEST_ROOT/work" config core.hooksPath .githooks
git -C "$TEST_ROOT/work" remote add origin "$TEST_ROOT/remote.git"
git -C "$TEST_ROOT/work" push -q -u origin main
expected_origin_url="$(git -C "$TEST_ROOT/work" remote get-url origin)"

old_main_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"
printf 'remote main advanced\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'advance remote main'
remote_main_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"
git -C "$TEST_ROOT/work" push -q origin main
git -C "$TEST_ROOT/work" update-ref refs/heads/main "$old_main_sha"

output="$(REPO_ROOT="$TEST_ROOT/work" "$CREATE" --branch codex/example --worktree "$TEST_ROOT/feature")"
case "$output" in
    *"created codex/example from origin/main at $remote_main_sha"*) ;;
    *)
        printf 'FAIL: unexpected create output (%s)\n' "$output" >&2
        exit 1
        ;;
esac

actual_sha="$(git -C "$TEST_ROOT/feature" rev-parse HEAD)"
if [ "$actual_sha" != "$remote_main_sha" ]; then
    printf 'FAIL: worktree did not start from origin/main (expected %s, got %s)\n' "$remote_main_sha" "$actual_sha" >&2
    exit 1
fi
test ! -e "$checkout_hook_log"

git -C "$TEST_ROOT/work" config filter.malicious.clean '!printf unsafe-filter'
set +e
filter_output="$(REPO_ROOT="$TEST_ROOT/work" "$CREATE" --branch codex/filter-example --worktree "$TEST_ROOT/feature-filter" 2>&1)"
filter_code=$?
set -e
if [ "$filter_code" -ne 20 ] || [[ "$filter_output" != *"unsafe executable or remote setting: filter.malicious.clean"* ]]; then
    printf 'FAIL: executable local filter config was not rejected (%s, %s)\n' "$filter_code" "$filter_output" >&2
    exit 1
fi
git -C "$TEST_ROOT/work" config --local --unset-all filter.malicious.clean

git -C "$TEST_ROOT/work" config --local credential.https://github.com.helper '!printf unsafe-credential-helper'
set +e
credential_helper_output="$(REPO_ROOT="$TEST_ROOT/work" "$CREATE" --branch codex/credential-helper-example --worktree "$TEST_ROOT/feature-credential-helper" 2>&1)"
credential_helper_code=$?
set -e
if [ "$credential_helper_code" -ne 20 ] || [[ "$credential_helper_output" != *"unsafe executable or remote setting: credential.https://github.com.helper"* ]]; then
    printf 'FAIL: URL-scoped credential helper config was not rejected (%s, %s)\n' "$credential_helper_code" "$credential_helper_output" >&2
    exit 1
fi
git -C "$TEST_ROOT/work" config --local --unset-all credential.https://github.com.helper

git -C "$TEST_ROOT/work" remote set-url origin 'git@github.com:silverThunder09/jdsnack-agent-os-project.git'
git -C "$TEST_ROOT/work" remote set-url --push origin 'git@github.com:silverThunder09/jdsnack-agent-os-project.git'
set +e
ssh_output="$(REPO_ROOT="$TEST_ROOT/work" "$CREATE" --branch codex/ssh-example --worktree "$TEST_ROOT/feature-ssh" 2>&1)"
ssh_code=$?
set -e
if [ "$ssh_code" -ne 20 ] || [[ "$ssh_output" != *"SSH remotes are not supported"* ]]; then
    printf 'FAIL: SSH remote was not rejected (%s, %s)\n' "$ssh_code" "$ssh_output" >&2
    exit 1
fi
git -C "$TEST_ROOT/work" remote set-url origin "$expected_origin_url"
git -C "$TEST_ROOT/work" remote set-url --push origin "$expected_origin_url"

windows_output="$(CODEX_WINDOWS_WORKTREE=true REPO_ROOT="$TEST_ROOT/work" "$CREATE" --branch codex/windows-example --worktree "$TEST_ROOT/feature-windows")"
case "$windows_output" in
    *"created codex/windows-example from origin/main at $remote_main_sha"*) ;;
    *)
        printf 'FAIL: unexpected standalone clone output (%s)\n' "$windows_output" >&2
        exit 1
        ;;
esac
test -d "$TEST_ROOT/feature-windows/.git"
test "$(git -C "$TEST_ROOT/feature-windows" rev-parse HEAD)" = "$remote_main_sha"
test "$(git -C "$TEST_ROOT/feature-windows" branch --show-current)" = codex/windows-example
test "$(git -C "$TEST_ROOT/feature-windows" remote get-url origin)" = "$expected_origin_url"
disabled_hooks_path="$(git -C "$TEST_ROOT/feature-windows" config --local --get core.hooksPath)"
case "$disabled_hooks_path" in
    /dev/null|nul) ;;
    *)
        printf 'FAIL: standalone clone hooks are not disabled (%s)\n' "$disabled_hooks_path" >&2
        exit 1
        ;;
esac
test -n "$(git -C "$TEST_ROOT/feature-windows" config --local --get jdsnack.hookBash)"
test -f "$TEST_ROOT/feature-windows/.githooks/pre-push"
test ! -e "$checkout_hook_log"

# A checkout-controlled pre-commit hook must not execute while Codex commits.
printf '#!/bin/sh\n: > %s\n' "$commit_hook_log" > "$TEST_ROOT/feature-windows/.githooks/pre-commit"
chmod +x "$TEST_ROOT/feature-windows/.githooks/pre-commit"
git -C "$TEST_ROOT/feature-windows" config user.name test
git -C "$TEST_ROOT/feature-windows" config user.email test@example.com
printf 'codex change\n' > "$TEST_ROOT/feature-windows/codex-change.txt"
git -C "$TEST_ROOT/feature-windows" add codex-change.txt
git -C "$TEST_ROOT/feature-windows" commit -qm 'codex commit'
test ! -e "$commit_hook_log"

printf 'Codex worktree creation tests passed\n'
printf 'Windows-compatible standalone clone contract passed\n'
