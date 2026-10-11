#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISH_SOURCE="$ROOT_DIR/scripts/publish-codex-branch.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-publish.XXXXXX")"
malicious_hook_log="$TEST_ROOT/malicious-hook.log"
trusted_hook_log="$TEST_ROOT/trusted-hook.log"
fake_tool_log="$TEST_ROOT/fake-tool.log"
PUBLISH_ROOT="$TEST_ROOT/publisher-root"
mkdir -p "$PUBLISH_ROOT/scripts"
cp "$PUBLISH_SOURCE" "$PUBLISH_ROOT/scripts/publish-codex-branch.sh"
cat > "$PUBLISH_ROOT/scripts/pre-push-ai-review.sh" <<EOF
#!/bin/sh
set -eu
if [ -n "\${GH_TOKEN-}" ] || [ -n "\${GITHUB_TOKEN-}" ] ||
    env | grep -Eq '^(GIT_CONFIG_[A-Za-z0-9_]*|GIT_ASKPASS|GIT_SSH|SSH_AUTH_SOCK|GH_)='; then
    printf 'trusted-hook-received-secret\\n' > '$trusted_hook_log'
    exit 1
fi
case "\${PATH-}" in
    *'$TEST_ROOT/work'*)
        printf 'trusted-hook-received-worktree-path\\n' > '$trusted_hook_log'
        exit 1
        ;;
esac
: > '$trusted_hook_log'
exit 0
EOF
chmod +x "$PUBLISH_ROOT/scripts/pre-push-ai-review.sh"
PUBLISH="$PUBLISH_ROOT/scripts/publish-codex-branch.sh"

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
git -C "$TEST_ROOT/work" config core.autocrlf false
for tool in git env bash; do
    cat > "$TEST_ROOT/work/$tool" <<EOF
#!/bin/sh
printf '%s\n' '$tool' >> '$fake_tool_log'
exit 93
EOF
    chmod +x "$TEST_ROOT/work/$tool"
done
printf 'initial\n' > "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add git env bash
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm initial
git -C "$TEST_ROOT/work" branch -M codex/example
git -C "$TEST_ROOT/work" remote add origin "$TEST_ROOT/remote.git"
git -C "$TEST_ROOT/work" push -q -u origin codex/example
git -C "$TEST_ROOT/work" push -q origin HEAD:refs/heads/main
real_bash="$(command -v bash)"
real_codex="$(command -v codex || true)"
base_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"

set +e
no_commit_output="$(CODEX_PUSH_ATTEMPTS=1 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/example --base-sha "$base_sha" 2>&1)"
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
if [ -n "${MALICIOUS_HOOK_LOG:-}" ]; then
    printf 'malicious hook received token=%s\n' "${GH_TOKEN-}" > "$MALICIOUS_HOOK_LOG"
fi
exit 91
EOF
chmod +x "$TEST_ROOT/hooks/pre-push"
git -C "$TEST_ROOT/work" config core.hooksPath "$TEST_ROOT/hooks"
set +e
output="$(PATH="$TEST_ROOT/bin:$TEST_ROOT/work:$PATH" MALICIOUS_HOOK_LOG="$malicious_hook_log" CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/example --base-sha "$base_sha")"
publish_code=$?
set -e
if [ -f "$fake_tool_log" ]; then
    printf 'fake tools invoked:\n' >&2
    cat "$fake_tool_log" >&2
fi
assert_eq 0 "$publish_code" "publish exit code"
case "$output" in
    *"codex push verified"*) ;;
    *)
        printf 'FAIL: publish output (%s)\n' "$output" >&2
        exit 1
        ;;
esac
test ! -e "$malicious_hook_log"
test -f "$trusted_hook_log"
test ! -e "$fake_tool_log"

remote_sha="$(git -C "$TEST_ROOT/work" ls-remote origin refs/heads/codex/example | awk 'NR == 1 { print $1 }')"
local_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"
assert_eq "$local_sha" "$remote_sha" "remote SHA"

git -C "$TEST_ROOT/work" switch -q -c codex/auth
auth_base_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"
printf 'authenticated publish\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'authenticated publish'
auth_output="$(PATH="$TEST_ROOT/work:$PATH" MALICIOUS_HOOK_LOG="$malicious_hook_log" GH_TOKEN=fixture-token GH_BIN=fixture-gh GH_CONFIG_DIR=fixture-gh-config GIT_DIR="$TEST_ROOT/remote.git" GIT_WORK_TREE="$TEST_ROOT" GIT_OBJECT_DIRECTORY="$TEST_ROOT" CODEX_BIN="$real_codex" GIT_ASKPASS=fixture-askpass GIT_SSH_COMMAND=fixture-ssh SSH_AUTH_SOCK=fixture-sock CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/auth --base-sha "$auth_base_sha")"
case "$auth_output" in
    *"codex push verified"*) ;;
    *)
        printf 'FAIL: authenticated publish output (%s)\n' "$auth_output" >&2
        exit 1
        ;;
esac
if grep -Fq "trusted-hook-received-secret" "$trusted_hook_log"; then
    printf 'FAIL: authenticated push exposed its token to the trusted pre-push hook\n' >&2
    exit 1
fi
test ! -e "$malicious_hook_log"

if [ -n "$real_codex" ]; then
    codex_path_output="$(PATH="$TEST_ROOT/work:$PATH" MALICIOUS_HOOK_LOG="$malicious_hook_log" GH_TOKEN=fixture-token GH_BIN=fixture-gh GH_CONFIG_DIR=fixture-gh-config CODEX_BIN="$real_codex" CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/auth --base-sha "$auth_base_sha" 2>&1)"
    case "$codex_path_output" in
        *"codex push verified"*) ;;
        *)
            printf 'FAIL: trusted Codex path publish output (%s)\n' "$codex_path_output" >&2
            exit 1
            ;;
    esac
fi

git -C "$TEST_ROOT/work" config http.https://github.com/.extraheader 'AUTHORIZATION: bearer existing-fixture'
existing_header_base_sha="$(git -C "$TEST_ROOT/work" rev-parse HEAD)"
printf 'existing checkout header\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'reuse existing checkout header'
set +e
existing_header_output="$(PATH="$TEST_ROOT/work:$PATH" MALICIOUS_HOOK_LOG="$malicious_hook_log" GH_TOKEN=fixture-token GH_BIN=fixture-gh GH_CONFIG_DIR=fixture-gh-config GIT_ASKPASS=fixture-askpass GIT_SSH_COMMAND=fixture-ssh SSH_AUTH_SOCK=fixture-sock CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/auth --base-sha "$existing_header_base_sha" 2>&1)"
existing_header_code=$?
set -e
assert_eq 0 "$existing_header_code" "existing-header publish exit code"
case "$existing_header_output" in
    *"codex push verified"*) ;;
    *)
        printf 'FAIL: existing-header publish output (%s)\n' "$existing_header_output" >&2
        exit 1
        ;;
esac

git -C "$TEST_ROOT/work" config --add http.https://github.com/.extraheader 'AUTHORIZATION: bearer duplicate-fixture'
set +e
duplicate_header_output="$(PATH="$TEST_ROOT/work:$PATH" GH_TOKEN=fixture-token GH_BIN=fixture-gh GH_CONFIG_DIR=fixture-gh-config CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/auth --base-sha "$existing_header_base_sha" 2>&1)"
duplicate_header_code=$?
set -e
assert_eq 20 "$duplicate_header_code" "duplicate-header exit code"
case "$duplicate_header_output" in
    *"multiple GitHub Authorization headers"*|*"could not refresh origin/main"*) ;;
    *)
        printf 'FAIL: duplicate-header output (%s)\n' "$duplicate_header_output" >&2
        exit 1
        ;;
esac
git -C "$TEST_ROOT/work" config --local --unset-all http.https://github.com/.extraheader
git -C "$TEST_ROOT/work" config http.https://github.com/.extraheader 'AUTHORIZATION: bearer existing-fixture'

git -C "$TEST_ROOT/work" remote set-url --push origin 'https://github.com.attacker.example/repository.git'
set +e
evil_remote_output="$(PATH="$TEST_ROOT/work:$PATH" GH_TOKEN=fixture-token GH_BIN=fixture-gh GH_CONFIG_DIR=fixture-gh-config CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/auth --base-sha "$existing_header_base_sha" 2>&1)"
evil_remote_code=$?
set -e
assert_eq 20 "$evil_remote_code" "non-GitHub remote exit code"
case "$evil_remote_output" in
    *"refusing authenticated Git operation for non-GitHub origin"*) ;;
    *)
        printf 'FAIL: non-GitHub remote output (%s)\n' "$evil_remote_output" >&2
        exit 1
        ;;
esac
git -C "$TEST_ROOT/work" remote set-url --push origin "$TEST_ROOT/remote.git"

git -C "$TEST_ROOT/work" remote set-url origin 'https://github.com/other-owner/other-repository.git'
git -C "$TEST_ROOT/work" remote set-url --push origin 'https://github.com/other-owner/other-repository.git'
set +e
same_host_output="$(GITHUB_REPOSITORY='silverThunder09/jdsnack-agent-os-project' GH_TOKEN=fixture-token CODEX_PUSH_ATTEMPTS=1 CODEX_PUSH_RETRY_DELAY_SECONDS=0 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/auth --base-sha "$existing_header_base_sha" 2>&1)"
same_host_code=$?
set -e
assert_eq 20 "$same_host_code" "same-host repository mismatch exit code"
case "$same_host_output" in
    *"refusing authenticated Git operation for non-GitHub origin"*) ;;
    *)
        printf 'FAIL: same-host repository mismatch output (%s)\n' "$same_host_output" >&2
        exit 1
        ;;
esac
git -C "$TEST_ROOT/work" remote set-url origin "$TEST_ROOT/remote.git"
git -C "$TEST_ROOT/work" remote set-url --push origin "$TEST_ROOT/remote.git"

set +e
mismatched_output="$(CODEX_PUSH_ATTEMPTS=1 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/other 2>&1)"
mismatched_code=$?
set -e
assert_eq 20 "$mismatched_code" "mismatched branch exit code"
case "$mismatched_output" in
    *"worktree branch does not match publish branch"*) ;;
    *) printf 'FAIL: mismatched branch output (%s)\n' "$mismatched_output" >&2; exit 1 ;;
esac
test -z "$(git -C "$TEST_ROOT/work" ls-remote origin refs/heads/codex/other)"

restored_hook_path="$(git -C "$TEST_ROOT/work" config --local --get core.hooksPath)"
test -n "$restored_hook_path"
git -C "$TEST_ROOT/work" config --local --unset core.hooksPath
git -C "$TEST_ROOT/work" fetch -q origin main
git -C "$TEST_ROOT/work" switch -q -c main refs/remotes/origin/main
printf 'remote main advanced\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'advance remote main'
git -C "$TEST_ROOT/work" push -q origin main
git -C "$TEST_ROOT/work" switch -q codex/example
printf 'stale feature change\n' >> "$TEST_ROOT/work/state.txt"
git -C "$TEST_ROOT/work" add state.txt
git -C "$TEST_ROOT/work" commit -qm 'stale feature change'

set +e
stale_output="$(CODEX_PUSH_ATTEMPTS=1 "$real_bash" "$PUBLISH" --worktree "$TEST_ROOT/work" --branch codex/example --base-sha "$local_sha" 2>&1)"
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
