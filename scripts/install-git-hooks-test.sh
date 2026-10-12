#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail 'git이 필요합니다.'
command -v bash >/dev/null 2>&1 || fail 'bash가 필요합니다.'

fixture_root="$(mktemp -d)"
test_worktree="$fixture_root/worktree"
fixture_bin="$fixture_root/bin"
cleanup() { rm -rf "$fixture_root"; }
trap cleanup EXIT

# The installer validates the Codex CLI contract, but this fixture only tests
# trusted source copying. Keep it independent from the runner's installed CLI.
mkdir -p "$fixture_bin"
printf '#!/bin/sh\nexit 0\n' > "$fixture_bin/codex"
chmod +x "$fixture_bin/codex"

# The checkout's origin/main may predate the trusted-bundle installer. Use the
# committed installer as the trusted fixture, then mutate only the worktree.
trusted_source_sha="$(git rev-parse HEAD)"
git clone --quiet --no-checkout "$ROOT_DIR" "$test_worktree"
git -C "$test_worktree" checkout -B codex/install-hook-test HEAD >/dev/null
git -C "$test_worktree" config user.name test
git -C "$test_worktree" config user.email test@example.com
git -C "$test_worktree" update-ref refs/remotes/origin/main "$trusted_source_sha"

cat > "$test_worktree/.githooks/pre-push" <<'EOF'
#!/bin/sh
printf '%s\n' branch-controlled-hook
EOF
cat > "$test_worktree/scripts/pre-push-ai-review.sh" <<'EOF'
#!/bin/sh
printf '%s\n' branch-controlled-reviewer
EOF
chmod +x "$test_worktree/.githooks/pre-push" "$test_worktree/scripts/pre-push-ai-review.sh"
cat > "$test_worktree/.githooks/pre-commit" <<'EOF'
#!/bin/sh
printf '%s\n' branch-controlled-pre-commit
EOF
cat > "$test_worktree/scripts/check-ai-readiness.py" <<'EOF'
raise SystemExit('branch-controlled-readiness')
EOF
chmod +x "$test_worktree/.githooks/pre-commit"
cat > "$test_worktree/scripts/install-git-hooks.sh" <<'EOF'
#!/bin/sh
echo branch-controlled-installer >&2
exit 99
EOF
chmod +x "$test_worktree/scripts/install-git-hooks.sh"

(
  cd "$test_worktree"
  git show refs/remotes/origin/main:scripts/install-git-hooks.sh | PATH="$fixture_bin:$PATH" sh >/dev/null
)

trusted_hooks_dir="$test_worktree/.git/jdsnack-hooks"
(
  cd "$test_worktree"
  MSYS_NO_PATHCONV=1 git show "refs/remotes/origin/main:.githooks/pre-push"
) | cmp - "$trusted_hooks_dir/pre-push" \
  || fail 'installer가 branch에서 변조한 pre-push를 trusted bundle에 복사했습니다.'
(
  cd "$test_worktree"
  MSYS_NO_PATHCONV=1 git show "refs/remotes/origin/main:scripts/pre-push-ai-review.sh"
) | cmp - "$trusted_hooks_dir/scripts/pre-push-ai-review.sh" \
  || fail 'installer가 branch에서 변조한 reviewer를 trusted bundle에 복사했습니다.'
(
  cd "$test_worktree"
  MSYS_NO_PATHCONV=1 git show "refs/remotes/origin/main:.githooks/pre-commit"
) | cmp - "$trusted_hooks_dir/pre-commit" \
  || fail 'installer가 branch에서 변조한 pre-commit을 trusted bundle에 복사했습니다.'
(
  cd "$test_worktree"
  MSYS_NO_PATHCONV=1 git show "refs/remotes/origin/main:scripts/check-ai-readiness.py"
) | cmp - "$trusted_hooks_dir/scripts/check-ai-readiness.py" \
  || fail 'installer가 branch에서 변조한 readiness 스크립트를 trusted bundle에 복사했습니다.'
test "$(<"$trusted_hooks_dir/trusted-source-sha")" = "$trusted_source_sha" \
  || fail 'trusted bundle이 독립 source SHA를 기록하지 않았습니다.'
test "$(<"$trusted_hooks_dir/trusted-source-ref")" = refs/remotes/origin/main \
  || fail '기본 installer가 origin/main source ref를 기록하지 않았습니다.'
configured_hooks_path="$(git -C "$test_worktree" config --local --get core.hooksPath)"
if command -v cygpath >/dev/null 2>&1; then
  configured_hooks_path="$(cygpath -u "$configured_hooks_path")"
fi
test "$configured_hooks_path" = "$trusted_hooks_dir" \
  || fail 'installer가 trusted 외부 core.hooksPath를 연결하지 않았습니다.'
configured_python_path="$(git -C "$test_worktree" config --local --get jdsnack.python)"
if command -v cygpath >/dev/null 2>&1; then
  configured_python_path="$(cygpath -u "$configured_python_path")"
fi
test -n "$configured_python_path" \
  || fail 'installer가 trusted pre-commit Python 경로를 저장하지 않았습니다.'
test -x "$configured_python_path" \
  || fail 'installer가 저장한 Python 경로가 실행 파일을 가리키지 않습니다.'
"$configured_python_path" --version >/dev/null 2>&1 \
  || fail 'installer가 저장한 Python 경로를 실행할 수 없습니다.'
(
  cd "$test_worktree"
  PATH="$fixture_bin:$PATH" "$trusted_hooks_dir/pre-commit" >/dev/null
) || fail 'trusted pre-commit이 branch 변조 readiness 스크립트를 실행했습니다.'

set +e
override_output="$(
  cd "$test_worktree"
  JDSNACK_HOOK_SOURCE_REF=HEAD PATH="$fixture_bin:$PATH" sh < <(git show refs/remotes/origin/main:scripts/install-git-hooks.sh) 2>&1
)"
override_status=$?
set -e
test "$override_status" -ne 0 \
  || fail 'installer가 branch-controlled trusted source override를 허용했습니다.'
grep -Fq 'trusted hook source override는 허용되지 않습니다' <<<"$override_output" \
  || fail 'installer가 trusted source override 차단 원인을 설명하지 않았습니다.'

echo 'Trusted hook installer requires the independent origin/main source'
