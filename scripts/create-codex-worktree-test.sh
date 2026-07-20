#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREATE="$ROOT_DIR/scripts/create-codex-worktree.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-worktree.XXXXXX")"

cleanup() {
    git -C "$TEST_ROOT/work" worktree remove --force "$TEST_ROOT/feature" >/dev/null 2>&1 || true
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

git init --bare -q "$TEST_ROOT/remote.git"
git init -q "$TEST_ROOT/work"
git -C "$TEST_ROOT/work" config user.name test
git -C "$TEST_ROOT/work" config user.email test@example.com
printf 'initial\n' > "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm initial
git -C "$TEST_ROOT/work" branch -M main
git -C "$TEST_ROOT/work" remote add origin "$TEST_ROOT/remote.git"
git -C "$TEST_ROOT/work" push -q -u origin main

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

printf 'Codex worktree creation tests passed\n'
