#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() {
  echo "FAIL: $1" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail 'git이 필요합니다.'
command -v bash >/dev/null 2>&1 || fail 'bash가 필요합니다.'
[[ -f "$ROOT_DIR/.githooks/pre-push" ]] || fail '.githooks/pre-push가 없습니다.'

fixture_root="$(mktemp -d)"
test_worktree="$fixture_root/worktree"
bare_remote="$fixture_root/remote.git"
hook_args_path="$fixture_root/hook-args.txt"
hook_refs_path="$fixture_root/hook-refs.txt"
branch_review_invoked_path="$fixture_root/branch-review-invoked"
ambient_bin="$fixture_root/ambient-bin"
ambient_capture="$fixture_root/ambient-git-config.txt"
trap 'rm -rf "$fixture_root"' EXIT

git init --bare --quiet "$bare_remote"
git clone --quiet "$ROOT_DIR" "$test_worktree"
branch_name='codex/pre-push-hook-contract'
git -C "$test_worktree" switch --quiet --create "$branch_name" HEAD
git -C "$test_worktree" remote set-url origin "$bare_remote"
trusted_hooks_root="$test_worktree/.git/jdsnack-hooks"
mkdir -p "$trusted_hooks_root/scripts"
cp "$ROOT_DIR/.githooks/pre-push" "$trusted_hooks_root/pre-push"
cp "$ROOT_DIR/.githooks/pre-commit" "$trusted_hooks_root/pre-commit"
cp "$ROOT_DIR/scripts/check-ai-readiness.py" "$trusted_hooks_root/scripts/check-ai-readiness.py"
cp "$ROOT_DIR/backends.json" "$trusted_hooks_root/backends.json"
for script_name in \
  review-policy.json \
  review-risk.ps1 \
  secure-review-temp-acl.ps1 \
  verify-codex-auth-permissions.ps1 \
  codex-auth-permissions.ps1 \
  review-path-safety.ps1; do
  cp "$ROOT_DIR/scripts/$script_name" "$trusted_hooks_root/scripts/$script_name"
done
git -C "$test_worktree" config --local jdsnack.hookBash "$(command -v bash)"
git -C "$test_worktree" config --local core.hooksPath "$trusted_hooks_root"

cat > "$trusted_hooks_root/scripts/pre-push-ai-review.sh" <<'FAKE_REVIEW'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${JDSNACK_HOOK_ARGS_CAPTURE:?}"
cat > "${JDSNACK_HOOK_REFS_CAPTURE:?}"
FAKE_REVIEW
cat > "$test_worktree/scripts/pre-push-ai-review.sh" <<'BRANCH_REVIEW'
#!/usr/bin/env bash
printf '%s\n' branch-controlled-review-invoked > "${JDSNACK_BRANCH_REVIEW_INVOKED:?}"
exit 91
BRANCH_REVIEW

chmod +x "$trusted_hooks_root/pre-push" "$trusted_hooks_root/scripts/pre-push-ai-review.sh" "$test_worktree/scripts/pre-push-ai-review.sh"
mkdir -p "$ambient_bin"
real_env="$(command -v env)"
real_sed="$(command -v sed)"
cat > "$ambient_bin/env" <<'FAKE_ENV'
#!/bin/sh
if [ -n "${GIT_CONFIG_VALUE_0-}" ]; then
  printf '%s\n' "$GIT_CONFIG_VALUE_0" >> "${JDSNACK_AMBIENT_CAPTURE:?}"
fi
exec "${JDSNACK_REAL_ENV:?}" "$@"
FAKE_ENV
cat > "$ambient_bin/sed" <<'FAKE_SED'
#!/bin/sh
if [ -n "${GIT_CONFIG_VALUE_0-}" ]; then
  printf '%s\n' "$GIT_CONFIG_VALUE_0" >> "${JDSNACK_AMBIENT_CAPTURE:?}"
fi
exec "${JDSNACK_REAL_SED:?}" "$@"
FAKE_SED
chmod +x "$ambient_bin/env" "$ambient_bin/sed"
head_sha="$(git -C "$test_worktree" rev-parse HEAD)"
git -C "$test_worktree" update-ref refs/remotes/origin/main "$head_sha"
printf '%s\n' "$head_sha" > "$trusted_hooks_root/source-sha"
printf '%s\n' "$head_sha" > "$trusted_hooks_root/trusted-source-sha"
printf '%s\n' refs/remotes/origin/main > "$trusted_hooks_root/trusted-source-ref"
bundle_manifest="$trusted_hooks_root/bundle-manifest"
: > "$bundle_manifest"
for bundle_path in \
  pre-commit \
  pre-push \
  scripts/check-ai-readiness.py \
  backends.json \
  scripts/pre-push-ai-review.sh \
  scripts/review-policy.json \
  scripts/review-risk.ps1 \
  scripts/secure-review-temp-acl.ps1 \
  scripts/verify-codex-auth-permissions.ps1 \
  scripts/codex-auth-permissions.ps1 \
  scripts/review-path-safety.ps1; do
  printf '%s %s\n' "$bundle_path" "$(git -C "$test_worktree" hash-object "$trusted_hooks_root/$bundle_path")" >> "$bundle_manifest"
done
remote_ref="refs/heads/$branch_name"
zero_sha='0000000000000000000000000000000000000000'
JDSNACK_HOOK_ARGS_CAPTURE="$hook_args_path" \
  JDSNACK_HOOK_REFS_CAPTURE="$hook_refs_path" \
  JDSNACK_BRANCH_REVIEW_INVOKED="$branch_review_invoked_path" \
  JDSNACK_AMBIENT_CAPTURE="$ambient_capture" \
  JDSNACK_REAL_ENV="$real_env" \
  JDSNACK_REAL_SED="$real_sed" \
  PATH="$ambient_bin:$PATH" \
  GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0=http.extraHeader \
  GIT_CONFIG_VALUE_0='Authorization: bearer fixture' \
  git -C "$test_worktree" push --dry-run origin "$branch_name:$remote_ref" >/dev/null

[[ -f "$hook_args_path" ]] || fail '실제 git push가 .githooks/pre-push를 호출하지 않았습니다.'
mapfile -t hook_args < "$hook_args_path"
[[ "${#hook_args[@]}" -eq 2 && "${hook_args[0]}" == 'origin' ]] \
  || fail '실제 git push가 pre-push hook 인자를 정상 전달하지 않았습니다.'

expected_refs="refs/heads/$branch_name $head_sha $remote_ref $zero_sha"
actual_refs="$(<"$hook_refs_path")"
[[ "$actual_refs" == "$expected_refs" ]] \
  || fail "실제 git push ref 입력이 hook 경계를 통과하지 않았습니다 (받음: ${actual_refs:-<empty>})."
[[ ! -e "$branch_review_invoked_path" ]] \
  || fail 'branch checkout의 pre-push 리뷰 스크립트가 실행되었습니다.'
[[ ! -e "$ambient_capture" ]] \
  || fail 'pre-push가 외부 helper를 실행하기 전에 GIT_CONFIG_* 민감값을 정리하지 않았습니다.'

if git --git-dir="$bare_remote" show-ref --verify --quiet "$remote_ref"; then
  fail '--dry-run 테스트가 bare remote를 변경했습니다.'
fi

echo 'Actual Git pre-push hook invocation forwarded ref input'
