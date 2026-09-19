#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_SCRIPT="$ROOT_DIR/scripts/sync-main-checkout.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-sync-main-test.XXXXXX")"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

REMOTE="$TEST_ROOT/remote.git"
SEED="$TEST_ROOT/seed"
CHECKOUT="$TEST_ROOT/checkout"

git init --bare "$REMOTE" >/dev/null
git init -b main "$SEED" >/dev/null
git -C "$SEED" config user.name 'JDSnack Harness Test'
git -C "$SEED" config user.email 'harness@example.invalid'
git -C "$SEED" remote add origin "$REMOTE"

printf 'base\n' > "$SEED/payload.txt"
git -C "$SEED" add payload.txt
git -C "$SEED" commit -m 'test: seed main' >/dev/null
git -C "$SEED" push -u origin main >/dev/null
git -C "$REMOTE" symbolic-ref HEAD refs/heads/main
git clone --quiet -b main "$REMOTE" "$CHECKOUT"
git -C "$CHECKOUT" config user.name 'JDSnack Harness Test'
git -C "$CHECKOUT" config user.email 'harness@example.invalid'

run_sync() {
    REPO_ROOT="$1" bash "$SYNC_SCRIPT"
}

expect_failure() {
    local repo="$1"
    local expected="$2"
    local output
    local status

    set +e
    output="$(REPO_ROOT="$repo" bash "$SYNC_SCRIPT" 2>&1)"
    status=$?
    set -e

    test "$status" -eq 20 || {
        printf 'expected exit code 20, got %s\n%s\n' "$status" "$output" >&2
        exit 1
    }
    printf '%s\n' "$output" | grep -Fq -- "$expected" || {
        printf 'expected failure text %s, got:\n%s\n' "$expected" "$output" >&2
        exit 1
    }
}

run_sync "$CHECKOUT"

printf 'remote update\n' > "$SEED/payload.txt"
git -C "$SEED" add payload.txt
git -C "$SEED" commit -m 'test: advance main' >/dev/null
git -C "$SEED" push origin main >/dev/null
run_sync "$CHECKOUT"
grep -Fxq 'remote update' "$CHECKOUT/payload.txt"
test "$(git -C "$CHECKOUT" rev-parse HEAD)" = "$(git -C "$CHECKOUT" rev-parse origin/main)"

printf 'dirty\n' > "$CHECKOUT/untracked.txt"
expect_failure "$CHECKOUT" 'uncommitted or untracked changes'
rm -f "$CHECKOUT/untracked.txt"

git -C "$CHECKOUT" switch -c feature >/dev/null
expect_failure "$CHECKOUT" 'must be on main'
git -C "$CHECKOUT" switch main >/dev/null

printf 'local ahead\n' > "$CHECKOUT/local.txt"
git -C "$CHECKOUT" add local.txt
git -C "$CHECKOUT" commit -m 'test: local ahead' >/dev/null
expect_failure "$CHECKOUT" 'local main is ahead'

printf 'sync-main-checkout contract passed\n'
