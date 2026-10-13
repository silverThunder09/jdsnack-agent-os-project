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
git -C "$test_worktree" config --local jdsnack.hookBash "$(command -v bash)"

cat > "$test_worktree/scripts/pre-push-ai-review.sh" <<'FAKE_REVIEW'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${JDSNACK_HOOK_ARGS_CAPTURE:?}"
cat > "${JDSNACK_HOOK_REFS_CAPTURE:?}"
FAKE_REVIEW

trusted_source_sha="$(git -C "$test_worktree" rev-parse --verify refs/remotes/origin/main^{commit} 2>/dev/null || git -C "$test_worktree" rev-parse HEAD)"
git -C "$test_worktree" update-ref refs/remotes/origin/main "$trusted_source_sha"
git_common_dir="$(git -C "$test_worktree" rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*|[A-Za-z]:[\\/]*) ;;
  *) git_common_dir="$test_worktree/$git_common_dir" ;;
esac
git_common_dir="$(CDPATH= cd -- "$git_common_dir" && pwd -P)"
trusted_hook_path="$git_common_dir/jdsnack-hooks"
mkdir -p "$trusted_hook_path/scripts"
chmod 700 "$trusted_hook_path" "$trusted_hook_path/scripts"
cp "$test_worktree/.githooks/pre-commit" "$trusted_hook_path/pre-commit"
cp "$test_worktree/.githooks/pre-push" "$trusted_hook_path/pre-push"
cp "$test_worktree/scripts/check-ai-readiness.py" "$trusted_hook_path/scripts/check-ai-readiness.py"
cp "$test_worktree/backends.json" "$trusted_hook_path/backends.json"
cp "$test_worktree/scripts/pre-push-ai-review.sh" "$trusted_hook_path/scripts/pre-push-ai-review.sh"
for script_name in \
  review-policy.json \
  review-risk.ps1 \
  secure-review-temp-acl.ps1 \
  verify-codex-auth-permissions.ps1 \
  verify-trusted-hook-bundle-acl.ps1 \
  codex-auth-permissions.ps1 \
  review-path-safety.ps1; do
  cp "$test_worktree/scripts/$script_name" "$trusted_hook_path/scripts/$script_name"
done
printf '%s\n' "$trusted_source_sha" > "$trusted_hook_path/source-sha"
printf '%s\n' "$trusted_source_sha" > "$trusted_hook_path/trusted-source-sha"
printf '%s\n' refs/remotes/origin/main > "$trusted_hook_path/trusted-source-ref"
: > "$trusted_hook_path/bundle-manifest"
write_manifest_entry() {
  local bundle_path="$1"
  printf '%s %s\n' "$bundle_path" \
    "$(git -C "$test_worktree" hash-object "$trusted_hook_path/$bundle_path")" \
    >> "$trusted_hook_path/bundle-manifest"
}
write_manifest_entry pre-commit
write_manifest_entry pre-push
write_manifest_entry scripts/check-ai-readiness.py
write_manifest_entry backends.json
write_manifest_entry scripts/pre-push-ai-review.sh
for script_name in \
  review-policy.json \
  review-risk.ps1 \
  secure-review-temp-acl.ps1 \
  verify-codex-auth-permissions.ps1 \
  verify-trusted-hook-bundle-acl.ps1 \
  codex-auth-permissions.ps1 \
  review-path-safety.ps1; do
  write_manifest_entry "scripts/$script_name"
done
chmod 700 "$trusted_hook_path/pre-commit" "$trusted_hook_path/pre-push" \
  "$trusted_hook_path/scripts/pre-push-ai-review.sh"
chmod 600 "$trusted_hook_path/source-sha" "$trusted_hook_path/trusted-source-sha" \
  "$trusted_hook_path/trusted-source-ref" "$trusted_hook_path/bundle-manifest"
configured_hook_path="$trusted_hook_path"
if command -v cygpath >/dev/null 2>&1; then
  configured_hook_path="$(cygpath -m "$trusted_hook_path")"
fi
git -C "$test_worktree" config --local core.hooksPath "$configured_hook_path"

head_sha="$(git -C "$test_worktree" rev-parse HEAD)"
remote_ref="refs/heads/$branch_name"
zero_sha='0000000000000000000000000000000000000000'
JDSNACK_HOOK_ARGS_CAPTURE="$hook_args_path" \
  JDSNACK_HOOK_REFS_CAPTURE="$hook_refs_path" \
  git -C "$test_worktree" push --dry-run origin "$branch_name:$remote_ref" >/dev/null

[[ -f "$hook_args_path" ]] || fail '실제 git push가 trusted pre-push hook을 호출하지 않았습니다.'
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
