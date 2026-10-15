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
trap 'rm -rf "$fixture_root"' EXIT

git init --bare --quiet "$bare_remote"
git clone --quiet "$ROOT_DIR" "$test_worktree"
branch_name='codex/pre-push-hook-contract'
git -C "$test_worktree" switch --quiet --create "$branch_name" HEAD
git -C "$test_worktree" remote set-url origin "$bare_remote"
git -C "$test_worktree" config --local core.hooksPath .githooks
git -C "$test_worktree" config --local jdsnack.hookBash "$(command -v bash)"

cat > "$test_worktree/scripts/pre-push-ai-review.sh" <<'FAKE_REVIEW'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${JDSNACK_HOOK_ARGS_CAPTURE:?}"
cat > "${JDSNACK_HOOK_REFS_CAPTURE:?}"
FAKE_REVIEW

head_sha="$(git -C "$test_worktree" rev-parse HEAD)"
remote_ref="refs/heads/$branch_name"
zero_sha='0000000000000000000000000000000000000000'
JDSNACK_HOOK_ARGS_CAPTURE="$hook_args_path" \
  JDSNACK_HOOK_REFS_CAPTURE="$hook_refs_path" \
  git -C "$test_worktree" push --dry-run origin "$branch_name:$remote_ref" >/dev/null

[[ -f "$hook_args_path" ]] || fail '실제 git push가 .githooks/pre-push를 호출하지 않았습니다.'
mapfile -t hook_args < "$hook_args_path"
[[ "${#hook_args[@]}" -eq 2 && "${hook_args[0]}" == 'origin' ]] \
  || fail '실제 git push가 pre-push hook 인자를 정상 전달하지 않았습니다.'

expected_refs="refs/heads/$branch_name $head_sha $remote_ref $zero_sha"
actual_refs="$(<"$hook_refs_path")"
[[ "$actual_refs" == "$expected_refs" ]] \
  || fail "실제 git push ref 입력이 hook 경계를 통과하지 않았습니다 (받음: ${actual_refs:-<empty>})."

if git --git-dir="$bare_remote" show-ref --verify --quiet "$remote_ref"; then
  fail '--dry-run 테스트가 bare remote를 변경했습니다.'
fi

echo 'Actual Git pre-push hook invocation forwarded ref input'
