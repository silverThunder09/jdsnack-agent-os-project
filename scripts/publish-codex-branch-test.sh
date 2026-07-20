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
