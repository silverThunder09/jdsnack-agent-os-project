#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail 'jq가 필요합니다.'
if command -v pwsh >/dev/null 2>&1; then
  pwsh_bin="$(command -v pwsh)"
elif command -v powershell.exe >/dev/null 2>&1; then
  pwsh_bin="$(command -v powershell.exe)"
else
  fail 'PowerShell이 필요합니다.'
fi

base_ref="${JDSNACK_REVIEW_BASE_REF:-origin/main}"
base_sha="$(git rev-parse --verify "$base_ref^{commit}")"
head_sha="$(git rev-parse HEAD)"
real_git_bin="$(command -v git)"
fake_root="$(mktemp -d)"
fixture_root="$(mktemp -d)"
test_worktree="$fixture_root/test-worktree"
git clone --quiet --no-checkout "$ROOT_DIR" "$test_worktree"
git -C "$test_worktree" checkout -B codex/pre-push-test "$head_sha" >/dev/null
# git clone intentionally excludes uncommitted source edits, so include the
# current hook implementation in the disposable fixture when it differs.
cp "$ROOT_DIR/scripts/pre-push-ai-review.sh" "$test_worktree/scripts/pre-push-ai-review.sh"
git -C "$test_worktree" add scripts/pre-push-ai-review.sh
if ! git -C "$test_worktree" diff --cached --quiet; then
  git -C "$test_worktree" -c user.name=review-test -c user.email=review-test@example.com \
    commit --quiet -m 'test: isolate current pre-push hook fixture'
fi
head_sha="$(git -C "$test_worktree" rev-parse HEAD)"
git -C "$test_worktree" update-ref refs/remotes/origin/main "$base_sha"
fixture_head_sha="$(git -C "$test_worktree" rev-parse HEAD)"
[ "$fixture_head_sha" = "$head_sha" ] || fail '격리 fixture가 현재 HEAD에서 생성되지 않았습니다.'
head_tree="$(git -C "$test_worktree" rev-parse "$head_sha^{tree}")"
non_ff_remote_sha="$(git -C "$test_worktree" -c user.name=review-test -c user.email=review-test@example.com commit-tree "$head_tree" -p "$base_sha" -m 'non-fast-forward pre-push fixture')"
if git -C "$test_worktree" merge-base --is-ancestor "$non_ff_remote_sha" "$head_sha"; then
  fail '격리 fixture의 non-fast-forward remote tip이 push head의 조상이 아닙니다.'
fi
workspace_arg="$test_worktree"
if command -v cygpath >/dev/null 2>&1; then
  workspace_arg="$(cygpath -w "$test_worktree")"
fi
if ! risk_json="$($pwsh_bin -NoProfile -File "$workspace_arg/scripts/review-risk.ps1" -Workspace "$workspace_arg" -BaseSha "$base_sha" -HeadSha "$head_sha")"; then
  fail '위험도 계산기가 fixture의 base/head를 처리하지 못했습니다.'
fi
expected_risk="$(jq -r '.riskBand' <<< "$risk_json")"
expected_score="$(jq -r '.riskScore' <<< "$risk_json")"
expected_labels="$(jq -r '.reviewLabels | join(", ")' <<< "$risk_json")"
test_cygpath_bin="$(command -v cygpath || true)"
test_icacls_bin="$(command -v icacls.exe || command -v icacls || true)"
test_sleep_bin="$(command -v sleep || true)"
test_stat_bin="$(command -v stat || true)"
test_tail_bin="$(command -v tail || true)"
[ -n "$test_sleep_bin" ] || fail 'sleep가 필요합니다.'
[ -n "$test_stat_bin" ] || fail 'stat가 필요합니다.'
[ -n "$test_tail_bin" ] || fail 'tail가 필요합니다.'
if [ -n "$test_cygpath_bin" ] && [ -z "$test_icacls_bin" ]; then
  fail 'Windows ACL 검증을 위해 icacls가 필요합니다.'
fi
interrupted_hook_pid=""
export JDSNACK_TEST_SECRET_TOKEN='must-be-cleared-before-review'
export JDSNACK_TEST_CUSTOM='must-be-cleared-by-allowlist'

printf '%s\n' "$expected_risk" > "$fake_root/expected-risk"
printf '%s\n' "$expected_score" > "$fake_root/expected-risk-score"
printf '%s\n' "$expected_labels" > "$fake_root/expected-labels"

cleanup() {
  if [ -n "$interrupted_hook_pid" ]; then
    kill -TERM "$interrupted_hook_pid" 2>/dev/null || true
    wait "$interrupted_hook_pid" 2>/dev/null || true
  fi
  rm -rf "$fake_root"
  rm -rf "$fixture_root"
}
trap cleanup EXIT

cat > "$fake_root/codex" <<'FAKE_CODEX'
#!/bin/sh
set -eux

runtime_dependency="${0%/*}/codex-runtime.sh"
if [ ! -f "$runtime_dependency" ]; then
  printf 'missing sibling runtime dependency: %s\n' "$runtime_dependency" >&2
  exit 17
fi
. "$runtime_dependency"
if [ "${CODEX_FIXTURE_RUNTIME_DEPENDENCY-}" != 'available' ]; then
  exit 18
fi

fixture_dir='__FAKE_ROOT__'
: > "$fixture_dir/runtime-dependency-invoked"
output_path=""
help_requested=0
read_only_sandbox_seen=0
workspace_write_network_config_seen=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help)
      help_requested=1
      ;;
    --config)
      shift
      if [ "${1:-}" = 'sandbox_workspace_write.network_access=false' ]; then
        workspace_write_network_config_seen=1
      fi
      ;;
    --sandbox)
      shift
      if [ "${1:-}" = 'read-only' ]; then
        read_only_sandbox_seen=1
      fi
      ;;
    --output-last-message)
      shift
      output_path="${1:-}"
      ;;
  esac
  shift
done

printf '%s\n' "$0" > "$fixture_dir/codex.invoked"
case "$0" in
  */reviewer-bin/codex|*\\reviewer-bin\\codex)
    : > "$fixture_dir/copied-entry-invoked"
    ;;
  *)
    : > "$fixture_dir/original-entry-invoked"
    ;;
esac
[ "$help_requested" -eq 1 ] && exit 0
[ -n "$output_path" ] || exit 2
[ "$read_only_sandbox_seen" -eq 1 ] || exit 9
[ "$workspace_write_network_config_seen" -eq 0 ] || exit 16
case "${PATH-}" in
  */reviewer-bin) ;;
  *) exit 3 ;;
esac
if command -v git >/dev/null 2>&1; then
  exit 4
fi
for forbidden_tool in git gh bash pwsh powershell.exe python python3 node; do
  if command -v "$forbidden_tool" >/dev/null 2>&1; then
    exit 14
  fi
done
if [ -n "${GIT_DIR-}" ] || [ -n "${GIT_WORK_TREE-}" ]; then
  exit 15
fi
if [ -n "${HOME-}" ] || [ -n "${USERPROFILE-}" ] || [ -n "${HOMEDRIVE-}" ] || [ -n "${HOMEPATH-}" ]; then
  exit 5
fi
if [ -n "${JDSNACK_TEST_SECRET_TOKEN-}" ]; then
  exit 6
fi
if [ -n "${JDSNACK_TEST_CUSTOM-}" ]; then
  exit 7
fi
if [ -n "${APPDATA-}" ] || [ -n "${LOCALAPPDATA-}" ]; then
  exit 11
fi
if [ -z "${SystemRoot-}" ] || [ -z "${WINDIR-}" ]; then
  exit 13
fi
case "${PWD-}" in
  *test-worktree*) exit 12 ;;
esac
case "${CODEX_HOME-}" in
  *review-fallback*) ;;
  *) exit 10 ;;
esac
printf '%s\n' "${TEMP-}" "${TMP-}" "${TMPDIR-}" "$CODEX_HOME" > "$fixture_dir/reviewer-temp-values"
if [ -f "$fixture_dir/codex.wait-for-signal" ]; then
  printf '%s\n' "$CODEX_HOME/auth.json" > "$fixture_dir/copied-auth-path"
  : > "$fixture_dir/codex.waiting"
  while [ -f "$fixture_dir/codex.wait-for-signal" ]; do
    "$fixture_dir/sleep-one-second"
  done
fi
IFS= read -r fake_risk < "$fixture_dir/expected-risk"
IFS= read -r fake_risk_score < "$fixture_dir/expected-risk-score"
IFS= read -r fake_labels < "$fixture_dir/expected-labels"
fake_score="${JDSNACK_FAKE_SCORE:-5}"
if [ -f "$fixture_dir/codex.invalid-score" ]; then
  fake_score=6
fi
if [ -f "$fixture_dir/codex.bad-risk" ]; then
  fake_risk='Light'
fi
case "$output_path" in
  *\\*)
    [ -x "$fixture_dir/cygpath" ] || exit 8
    output_path="$("$fixture_dir/cygpath" -u "$output_path")"
    ;;
esac

if [ -f "$fixture_dir/codex.rotate-auth" ] || [ -f "$fixture_dir/codex.change-source-auth" ] || [ -f "$fixture_dir/codex.record-auth" ]; then
  review_auth_path="$CODEX_HOME/auth.json"
  case "$review_auth_path" in
    *\\*)
      [ -x "$fixture_dir/cygpath" ] || exit 19
      review_auth_path="$("$fixture_dir/cygpath" -u "$review_auth_path")"
      ;;
  esac
  if [ -f "$fixture_dir/codex.rotate-auth" ]; then
    printf '%s\n' '{"auth_mode":"chatgpt","tokens":{"access_token":"rotated-access","refresh_token":"rotated-refresh","account_id":"synthetic-account"},"account_id":"synthetic-account"}' > "$review_auth_path"
  fi
  if [ -f "$fixture_dir/codex.change-source-auth" ]; then
    IFS= read -r rotating_auth_source < "$fixture_dir/rotating-auth-source-path"
    printf '%s\n' '{"auth_mode":"chatgpt","tokens":{"access_token":"concurrent-access","refresh_token":"concurrent-refresh","account_id":"synthetic-account"},"account_id":"synthetic-account","client_id":"preserve-this-metadata"}' > "$rotating_auth_source"
  fi
  if [ -f "$fixture_dir/codex.record-auth" ]; then
    while IFS= read -r auth_line; do
      printf '%s\n' "$auth_line" >> "$fixture_dir/recorded-reviewer-auth.json"
    done < "$review_auth_path"
  fi
fi
if [ -f "$fixture_dir/codex.change-source-ref" ]; then
  "$fixture_dir/mutate-source-ref"
fi

{
  printf 'decision: %s\n' "${JDSNACK_FAKE_DECISION:-PASS}"
  printf 'score: %s\n' "$fake_score"
  printf 'risk: %s\n' "$fake_risk"
  printf 'risk_score: %s\n' "$fake_risk_score"
  printf 'review_labels: %s\n' "$fake_labels"
  printf 'findings:\n'
} > "$output_path"
if [ -f "$fixture_dir/codex.blocking" ]; then
  printf '%s\n' '- P1 — synthetic blocker' >> "$output_path"
else
  printf '%s\n' '- none' >> "$output_path"
fi
if [ -f "$fixture_dir/codex.duplicate" ]; then
  printf '%s\n' 'decision: REQUEST_CHANGES' >> "$output_path"
fi
if [ -f "$fixture_dir/codex.duplicate-risk-score" ]; then
  printf '%s\n' 'risk_score: malformed duplicate' >> "$output_path"
fi
if [ -f "$fixture_dir/codex.duplicate-review-labels" ]; then
  printf '%s\n' 'review_labels: malformed duplicate' >> "$output_path"
fi
if [ -f "$fixture_dir/codex.malformed-findings" ]; then
  printf '%s\n' '- informational finding without a severity prefix' >> "$output_path"
fi
if [ -f "$fixture_dir/codex.failure" ]; then
  printf '%s\n' 'synthetic reviewer failure' >&2
  exit 8
fi
{
  printf 'review_summary:\n'
  if [ -f "$fixture_dir/codex.weak-summary" ]; then
    printf 'insufficient summary\n'
  else
    fake_score="${JDSNACK_FAKE_SCORE:-5}"
    fake_first_rubric_status='PASS'
    if [ -f "$fixture_dir/codex.ok-summary" ]; then
      fake_first_rubric_status='OK'
    elif [ -f "$fixture_dir/codex.satisfied-summary" ]; then
      fake_first_rubric_status='SATISFIED'
    fi
    printf '%s\n' "- correctness: ${fake_first_rubric_status} — the reviewed diff has a coherent implementation."
    printf '%s\n' '- contract: PASS — the requested workflow contracts are covered.'
    printf '%s\n' '- tests: PASS — executable contract tests cover the changed paths.'
    printf '%s\n' '- security: PASS — restricted execution and fail-closed checks are preserved.'
    printf '%s\n' '- maintainability: PASS — the change keeps validation responsibilities explicit.'
    printf '%s\n' "- score rationale: ${fake_score}/5 — all five rubric items have concrete passing evidence."
    printf '%s\n' '- conclusion: the reviewed change is safe and complete for this push.'
  fi
} >> "$output_path"
if [ -f "$fixture_dir/codex.duplicate-summary" ]; then
  printf '%s\n' '- correctness: PASS — duplicate rubric evidence must be rejected.' >> "$output_path"
  printf '%s\n' '- conclusion: duplicate conclusion evidence must be rejected.' >> "$output_path"
fi
FAKE_CODEX
printf '%s\n' 'CODEX_FIXTURE_RUNTIME_DEPENDENCY=available' > "$fake_root/codex-runtime.sh"
sed -i "s|__FAKE_ROOT__|$fake_root|g" "$fake_root/codex"
chmod +x "$fake_root/codex"
cat > "$fake_root/pwsh" <<'FAKE_PWSH'
#!/bin/sh
set -eu

fixture_dir='__FAKE_ROOT__'
real_pwsh='__REAL_PWSH__'
if [ -f "$fixture_dir/pwsh.invalid-json" ]; then
  printf '%s\n' '{"riskScore":65}'
  exit 0
fi
if [ -f "$fixture_dir/pwsh.stderr-zero-exit" ]; then
  "$real_pwsh" "$@"
  printf '%s\n' 'synthetic PowerShell error with zero exit status' >&2
  exit 0
fi
exec "$real_pwsh" "$@"
FAKE_PWSH
sed -i "s|__FAKE_ROOT__|$fake_root|g; s|__REAL_PWSH__|$pwsh_bin|g" "$fake_root/pwsh"
chmod +x "$fake_root/pwsh"
if [ -n "$test_cygpath_bin" ]; then
  cat > "$fake_root/cygpath" <<'FAKE_CYGPATH'
#!/bin/sh
set -eu

fixture_dir='__FAKE_ROOT__'
real_cygpath='__REAL_CYGPATH__'
exec "$real_cygpath" "$@"
FAKE_CYGPATH
  sed -i "s|__FAKE_ROOT__|$fake_root|g; s|__REAL_CYGPATH__|$test_cygpath_bin|g" "$fake_root/cygpath"
  chmod +x "$fake_root/cygpath"
fi
printf '#!/bin/sh\nif [ "$#" -eq 0 ]; then set -- 1; fi\nexec "%s" "$@"\n' "$test_sleep_bin" > "$fake_root/sleep-one-second"
chmod +x "$fake_root/sleep-one-second"

set_origin_urls() {
  local origin_fetch_url="$1"
  local origin_push_url="$2"

  git -C "$test_worktree" remote set-url origin "$origin_fetch_url"
  git -C "$test_worktree" remote set-url --push origin "$origin_push_url"
}

run_hook_with_origin_urls() {
  local hook_path="$1"
  local destination_url="$2"
  local origin_fetch_url="$3"
  local origin_push_url="$4"

  set_origin_urls "$origin_fetch_url" "$origin_push_url"
  bash "$hook_path" origin "$destination_url"
}

run_review() {
  local canonical_origin_url='https://github.com/silverThunder09/jdsnack-agent-os-project'
  (
    cd "$test_worktree"
    printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$base_sha" \
      | PATH="$fake_root:$PATH" \
        JDSNACK_REVIEW_BASE_REF="$base_ref" \
        run_hook_with_origin_urls "$test_worktree/.githooks/pre-push" "$canonical_origin_url" "$canonical_origin_url" "$canonical_origin_url"
  )
}

default_codex_home="$fake_root/user-codex"
mkdir -p "$default_codex_home"
printf '%s\n' '{"auth_mode":"chatgpt","tokens":{"access_token":"default-access","refresh_token":"default-refresh","account_id":"synthetic-account"},"account_id":"synthetic-account"}' > "$default_codex_home/auth.json"
chmod 600 "$default_codex_home/auth.json"
export CODEX_HOME="$default_codex_home"
export CODEX_AUTH_FILE="$default_codex_home/auth.json"

implicit_user_home="$fake_root/implicit-user-home"
mkdir -p "$implicit_user_home/.codex"
printf '%s\n' '{"auth_mode":"chatgpt","tokens":{"access_token":"implicit-access","refresh_token":"implicit-refresh","account_id":"synthetic-account"},"account_id":"synthetic-account","client_id":"preserve-source-metadata"}' > "$implicit_user_home/.codex/auth.json"
chmod 600 "$implicit_user_home/.codex/auth.json"
rm -f "$fake_root/codex.invoked"
set +e
implicit_auth_output="$(CODEX_HOME= CODEX_AUTH_FILE= HOME="$implicit_user_home" run_review 2>&1)"
implicit_auth_status=$?
set -e
if [ "$implicit_auth_status" -eq 0 ] || ! grep -Fq 'set CODEX_HOME or CODEX_AUTH_FILE once to seed' <<< "$implicit_auth_output"; then
  printf '%s\n' "$implicit_auth_output" >&2
  fail 'pre-push가 명시적 seed 설정 없이 일반 사용자 Codex 로그인을 암묵적으로 사용했습니다.'
fi
if [ -e "$fake_root/codex.invoked" ] || [ -e "$implicit_user_home/.codex/review-fallback/auth.json" ]; then
  fail '명시적 인증 seed 없이 Codex reviewer 인증 홈을 만들거나 실행했습니다.'
fi
CODEX_HOME= CODEX_AUTH_FILE="$implicit_user_home/.codex/auth.json" HOME="$implicit_user_home" run_review >/dev/null
implicit_reviewer_auth="$implicit_user_home/.codex/review-fallback/auth.json"
if ! jq -e 'keys | sort == ["account_id", "auth_mode", "tokens"]' "$implicit_reviewer_auth" >/dev/null; then
  fail '명시적 초기 seed가 최소 Codex 인증 payload만 reviewer 홈에 저장하지 않았습니다.'
fi
if ! jq -e '.client_id == "preserve-source-metadata"' "$implicit_user_home/.codex/auth.json" >/dev/null; then
  fail '명시적 초기 seed가 원본 Codex 인증 파일의 메타데이터를 변경했습니다.'
fi
CODEX_HOME= CODEX_AUTH_FILE= HOME="$implicit_user_home" run_review >/dev/null
if ! jq -e '.tokens.access_token == "implicit-access"' "$implicit_reviewer_auth" >/dev/null; then
  fail '후속 리뷰가 사용자 원본 없이 영속 reviewer 인증 사본을 재사용하지 못했습니다.'
fi

cat > "$fake_root/mutate-source-ref" <<'MUTATE_SOURCE_REF'
#!/bin/sh
set -eu
git_bin='__REAL_GIT__'
test_worktree='__TEST_WORKTREE__'
head_sha='__HEAD_SHA__'
base_sha='__BASE_SHA__'
"$git_bin" -C "$test_worktree" update-ref --no-deref HEAD "$head_sha"
"$git_bin" -C "$test_worktree" update-ref refs/heads/codex/pre-push-test "$base_sha"
MUTATE_SOURCE_REF
sed -i "s|__REAL_GIT__|$real_git_bin|g; s|__TEST_WORKTREE__|$test_worktree|g; s|__HEAD_SHA__|$head_sha|g; s|__BASE_SHA__|$base_sha|g" "$fake_root/mutate-source-ref"
chmod +x "$fake_root/mutate-source-ref"

run_review >/dev/null

touch "$fake_root/codex.change-source-ref"
set +e
source_ref_changed_output="$(run_review 2>&1)"
source_ref_changed_status=$?
set -e
rm -f "$fake_root/codex.change-source-ref"
detached_head_sha="$(git -C "$test_worktree" rev-parse HEAD)"
changed_branch_sha="$(git -C "$test_worktree" rev-parse refs/heads/codex/pre-push-test)"
git -C "$test_worktree" symbolic-ref HEAD refs/heads/codex/pre-push-test
git -C "$test_worktree" update-ref refs/heads/codex/pre-push-test "$head_sha"
if [ "$source_ref_changed_status" -eq 0 ] || ! grep -Fq 'push source ref가 바뀌어' <<< "$source_ref_changed_output" || \
  [ "$detached_head_sha" != "$head_sha" ] || [ "$changed_branch_sha" != "$base_sha" ]; then
  printf '%s\n' "$source_ref_changed_output" >&2
  fail '리뷰 중 HEAD는 유지한 채 push source ref가 바뀐 상황을 pre-push가 차단하지 못했습니다.'
fi

rotating_auth_source="$fake_root/rotating-auth.json"
rotating_user_home="$fake_root/rotating-user-home"
mkdir -p "$rotating_user_home"
printf '%s\n' '{"auth_mode":"chatgpt","tokens":{"access_token":"initial-access","refresh_token":"initial-refresh","account_id":"synthetic-account"},"account_id":"synthetic-account","client_id":"preserve-this-metadata"}' > "$rotating_auth_source"
chmod 600 "$rotating_auth_source"
printf '%s\n' "$rotating_auth_source" > "$fake_root/rotating-auth-source-path"
touch "$fake_root/codex.rotate-auth" "$fake_root/codex.change-source-auth"
CODEX_HOME="$rotating_user_home" CODEX_AUTH_FILE="$rotating_auth_source" run_review >/dev/null
rm -f "$fake_root/codex.rotate-auth" "$fake_root/codex.change-source-auth"
if ! jq -e '.tokens.access_token == "concurrent-access" and .tokens.refresh_token == "concurrent-refresh" and .client_id == "preserve-this-metadata"' "$rotating_auth_source" >/dev/null; then
  fail 'Codex 리뷰가 동시 로그인으로 변경된 원본 인증 정보를 덮어썼습니다.'
fi
rotating_reviewer_auth="$rotating_user_home/review-fallback/auth.json"
if ! jq -e '.tokens.access_token == "rotated-access" and .tokens.refresh_token == "rotated-refresh"' "$rotating_reviewer_auth" >/dev/null; then
  fail 'Codex가 갱신한 토큰을 전용 reviewer 인증 홈에 보존하지 못했습니다.'
fi
touch "$fake_root/codex.record-auth"
CODEX_HOME="$rotating_user_home" CODEX_AUTH_FILE="$rotating_auth_source" run_review >/dev/null
rm -f "$fake_root/codex.record-auth"
if ! jq -e '.tokens.access_token == "rotated-access" and .tokens.refresh_token == "rotated-refresh"' "$fake_root/recorded-reviewer-auth.json" >/dev/null; then
  fail '후속 리뷰가 영속 reviewer 인증 홈의 갱신 토큰을 재사용하지 못했습니다.'
fi

linked_user_home="$fake_root/linked-user-home"
mkdir -p "$linked_user_home/review-fallback"
printf '%s\n' '{"auth_mode":"chatgpt","tokens":{"access_token":"linked-access","refresh_token":"linked-refresh","account_id":"synthetic-account"},"account_id":"synthetic-account"}' > "$linked_user_home/auth.json"
chmod 600 "$linked_user_home/auth.json"
ln "$linked_user_home/auth.json" "$linked_user_home/review-fallback/auth.json"
set +e
linked_auth_output="$(CODEX_HOME="$linked_user_home" CODEX_AUTH_FILE="$linked_user_home/auth.json" run_review 2>&1)"
linked_auth_status=$?
set -e
if [ "$linked_auth_status" -eq 0 ] || ! grep -Fq '단일 링크 regular file' <<< "$linked_auth_output"; then
  printf '%s\n' "$linked_auth_output" >&2
  fail 'pre-push가 사용자 원본과 hard link된 reviewer 인증 파일을 차단하지 않았습니다.'
fi
if ! jq -e '.tokens.access_token == "linked-access" and .tokens.refresh_token == "linked-refresh"' "$linked_user_home/auth.json" >/dev/null; then
  fail 'hard link 차단 과정에서 사용자 원본 인증 파일이 변경되었습니다.'
fi

mapfile -t reviewer_temp_values < "$fake_root/reviewer-temp-values"
if [ "${#reviewer_temp_values[@]}" -ne 4 ] || [ "${reviewer_temp_values[0]}" != "${reviewer_temp_values[1]}" ] || [ "${reviewer_temp_values[1]}" != "${reviewer_temp_values[2]}" ]; then
  fail '리뷰어 TEMP/TMP/TMPDIR이 같은 격리 디렉터리를 가리키지 않습니다.'
fi
if [ -n "$test_cygpath_bin" ]; then
  expected_codex_home_path="$("$test_cygpath_bin" -w "$rotating_user_home/review-fallback")"
else
  expected_codex_home_path="$rotating_user_home/review-fallback"
fi
if [ "${reviewer_temp_values[3]}" != "$expected_codex_home_path" ]; then
  fail 'Codex reviewer가 전용 영속 CODEX_HOME을 사용하지 않습니다.'
fi

printf '%s\n' '{"OPENAI_API_KEY":"synthetic-test-key"}' > "$fake_root/synthetic-auth.json"
chmod 600 "$fake_root/synthetic-auth.json"
touch "$fake_root/codex.wait-for-signal"
printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$base_sha" > "$fake_root/interrupted-push-input"
canonical_origin_url='https://github.com/silverThunder09/jdsnack-agent-os-project'
(
  cd "$test_worktree"
  export PATH="$fake_root:$PATH"
  export JDSNACK_REVIEW_BASE_REF="$base_ref"
  export CODEX_AUTH_FILE="$fake_root/synthetic-auth.json"
  export CODEX_HOME="$fake_root/interrupted-user-home"
  mkdir -p "$CODEX_HOME"
  exec bash "$test_worktree/scripts/pre-push-ai-review.sh" origin "$canonical_origin_url" < "$fake_root/interrupted-push-input"
) > "$fake_root/interrupted-hook.log" 2>&1 &
interrupted_hook_pid=$!
wait_attempt=0
while [ ! -e "$fake_root/codex.waiting" ] && [ "$wait_attempt" -lt 100 ]; do
  "$test_sleep_bin" 1
  wait_attempt=$((wait_attempt + 1))
done
if [ ! -e "$fake_root/codex.waiting" ]; then
  kill -TERM "$interrupted_hook_pid" 2>/dev/null || true
  wait "$interrupted_hook_pid" 2>/dev/null || true
  interrupted_hook_pid=""
  "$test_tail_bin" -n 20 "$fake_root/interrupted-hook.log" >&2 || true
  fail 'signal 정리 fixture가 Codex 리뷰 단계에 도달하지 않았습니다.'
fi
copied_auth_path="$(<"$fake_root/copied-auth-path")"
if [ -n "$test_cygpath_bin" ]; then
  copied_auth_path="$("$test_cygpath_bin" -u "$copied_auth_path")"
fi
if [ ! -f "$copied_auth_path" ]; then
  fail 'signal fixture에서 임시 인증 사본을 찾을 수 없습니다.'
fi
auth_file_mode="$("$test_stat_bin" -c '%a' "$copied_auth_path")"
codex_home_path="${copied_auth_path%/auth.json}"
review_lock_dir_path="$codex_home_path/.review-lock"
IFS= read -r temp_dir_path < "$fake_root/reviewer-temp-values"
case "$temp_dir_path" in
  *\\*)
    temp_dir_path="$("$test_cygpath_bin" -u "$temp_dir_path")"
    ;;
esac
codex_home_mode="$("$test_stat_bin" -c '%a' "$codex_home_path")"
temp_dir_mode="$("$test_stat_bin" -c '%a' "$temp_dir_path")"
if [ -n "$test_cygpath_bin" ]; then
  auth_acl="$("$test_icacls_bin" "$copied_auth_path")"
  if grep -Eiq 'Everyone|Authenticated Users|BUILTIN\\Users' <<< "$auth_acl"; then
    fail '임시 인증 파일 ACL에 광범위한 사용자 권한이 남아 있습니다.'
  fi
  for protected_path in "$temp_dir_path" "$codex_home_path" "$copied_auth_path"; do
    protected_windows_path="$("$test_cygpath_bin" -w "$protected_path")"
    if ! "$pwsh_bin" -NoProfile -File "$test_worktree/scripts/secure-review-temp-acl.ps1" \
      -Path "$protected_windows_path" -VerifyOnly >/dev/null; then
      fail '임시 리뷰 경로 ACL이 현재 제한 실행 환경의 허용 목록과 다릅니다.'
    fi
  done
elif [ "$auth_file_mode" != '600' ] || [ "$codex_home_mode" != '700' ] || [ "$temp_dir_mode" != '700' ]; then
  fail "임시 인증 파일/디렉터리 권한이 제한되지 않았습니다 (auth=$auth_file_mode codex_home=$codex_home_mode temp=$temp_dir_mode)."
fi
kill -TERM "$interrupted_hook_pid"
set +e
wait "$interrupted_hook_pid"
interrupted_hook_status=$?
set -e
interrupted_hook_pid=""
rm -f "$fake_root/codex.wait-for-signal"
if [ "$interrupted_hook_status" -ne 143 ] || [ -e "$temp_dir_path" ]; then
  "$test_tail_bin" -n 20 "$fake_root/interrupted-hook.log" >&2 || true
  fail 'TERM 중단 시 임시 디렉터리가 정리되지 않았거나 전용 reviewer 인증 홈이 삭제되었습니다.'
fi
if [ ! -f "$copied_auth_path" ] || [ -e "$review_lock_dir_path" ]; then
  fail 'TERM 중단 시 영속 reviewer 인증 정보가 보존되지 않았거나 사용 lock이 정리되지 않았습니다.'
fi

for risk_failure in invalid-json stderr-zero-exit; do
  touch "$fake_root/pwsh.$risk_failure"
  rm -f "$fake_root/codex.invoked"
  set +e
  risk_failure_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
    | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
        JDSNACK_REVIEW_BASE_REF="$base_ref" \
        bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
  risk_failure_status=$?
  set -e
  rm -f "$fake_root/pwsh.$risk_failure"
  if [ "$risk_failure_status" -eq 0 ] || ! grep -Fq '결정론적 pre-push 위험도' <<< "$risk_failure_output"; then
    printf '%s\n' "$risk_failure_output" >&2
    fail "위험도 계산의 $risk_failure 결과를 pre-push가 차단하지 않았습니다."
  fi
  if [ -e "$fake_root/codex.invoked" ]; then
    fail "위험도 계산의 $risk_failure 결과가 Codex 리뷰 실행 전에 차단되지 않았습니다."
  fi
done

if [ ! -e "$fake_root/original-entry-invoked" ] || [ ! -e "$fake_root/runtime-dependency-invoked" ]; then
  fail 'Codex reviewer가 원본 실행 경로와 형제 runtime dependency를 보존하지 않았습니다.'
fi
if [ -e "$fake_root/copied-entry-invoked" ]; then
  fail 'Codex reviewer가 runtime sidecar가 분리되는 복사 실행 파일을 사용했습니다.'
fi

fork_origin_url='https://github.com/example-user/jdsnack-agent-os-project.git'
rm -f "$fake_root/codex.invoked"
(
  cd "$test_worktree"
  printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$base_sha" \
    | PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      run_hook_with_origin_urls "$test_worktree/scripts/pre-push-ai-review.sh" "$fork_origin_url" "$fork_origin_url" "$fork_origin_url"
) >/dev/null
if [ ! -e "$fake_root/codex.invoked" ]; then
  fail 'fork origin의 동일 repository push가 Codex reviewer까지 진행되지 않았습니다.'
fi

rm -f "$fake_root/codex.invoked"
set +e
origin_identity_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      run_hook_with_origin_urls "$test_worktree/scripts/pre-push-ai-review.sh" https://github.com/silverThunder09/jdsnack-agent-os-project https://github.com/silverThunder09/jdsnack-agent-os-project "$fork_origin_url") 2>&1)"
origin_identity_status=$?
set -e
if [ "$origin_identity_status" -eq 0 ] || ! grep -Fq '같은 GitHub repository' <<< "$origin_identity_output"; then
  printf '%s\n' "$origin_identity_output" >&2
  fail 'origin fetch/push repository 불일치를 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail 'origin repository 불일치가 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi
set_origin_urls https://github.com/silverThunder09/jdsnack-agent-os-project https://github.com/silverThunder09/jdsnack-agent-os-project

rm -f "$fake_root/codex.invoked"
set +e
tag_output="$(printf 'refs/tags/v1.0.0 %s refs/tags/v1.0.0 %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
tag_status=$?
set -e
if [ "$tag_status" -eq 0 ] || ! grep -Fq 'branch push만 허용됩니다' <<< "$tag_output"; then
  printf '%s\n' "$tag_output" >&2
  fail 'tag ref push를 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail 'tag ref push가 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

set +e
remote_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" upstream https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
remote_status=$?
set -e
if [ "$remote_status" -eq 0 ] || ! grep -Fq 'remote는 origin으로 고정' <<< "$remote_output"; then
  printf '%s\n' "$remote_output" >&2
  fail 'origin 이외 remote push를 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail 'origin 이외 remote push가 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

set +e
url_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://evil.example) 2>&1)"
url_status=$?
set -e
if [ "$url_status" -eq 0 ] || ! grep -Fq 'destination URL은 GitHub owner/repository' <<< "$url_output"; then
  printf '%s\n' "$url_output" >&2
  fail 'origin push URL override를 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail 'origin push URL override가 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

rm -f "$fake_root/codex.invoked"
set +e
non_ff_remote_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$non_ff_remote_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
non_ff_remote_status=$?
set -e
if [ "$non_ff_remote_status" -eq 0 ] || ! grep -Fq 'non-fast-forward/force push' <<< "$non_ff_remote_output"; then
  printf '%s\n' "$non_ff_remote_output" >&2
  fail 'push 대상 HEAD와 무관한 기존 remote tip을 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail 'non-fast-forward remote tip이 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

touch "$fake_root/codex.weak-summary"
set +e
weak_summary_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
weak_summary_status=$?
set -e
rm -f "$fake_root/codex.weak-summary"
if [ "$weak_summary_status" -eq 0 ] || ! grep -Fq '5개 rubric' <<< "$weak_summary_output"; then
  printf '%s\n' "$weak_summary_output" >&2
  fail '실질적인 rubric 근거가 없는 review_summary를 pre-push가 차단하지 않았습니다.'
fi

for unsupported_rubric_status in OK SATISFIED; do
  case "$unsupported_rubric_status" in
    OK) invalid_summary_marker="$fake_root/codex.ok-summary" ;;
    SATISFIED) invalid_summary_marker="$fake_root/codex.satisfied-summary" ;;
  esac
  touch "$invalid_summary_marker"
  set +e
  unsupported_summary_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
    | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
        JDSNACK_REVIEW_BASE_REF="$base_ref" \
        bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
  unsupported_summary_status=$?
  set -e
  rm -f "$invalid_summary_marker"
  if [ "$unsupported_summary_status" -eq 0 ] || ! grep -Fq '5개 rubric' <<< "$unsupported_summary_output"; then
    printf '%s\n' "$unsupported_summary_output" >&2
    fail "review_summary rubric의 $unsupported_rubric_status 상태를 pre-push가 차단하지 않았습니다."
  fi
done

set +e
touch "$fake_root/codex.duplicate-summary"
duplicate_summary_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
duplicate_summary_status=$?
set -e
rm -f "$fake_root/codex.duplicate-summary"
if [ "$duplicate_summary_status" -eq 0 ] || ! grep -Fq '5개 rubric' <<< "$duplicate_summary_output"; then
  printf '%s\n' "$duplicate_summary_output" >&2
  fail '중복 rubric·conclusion review_summary를 pre-push가 차단하지 않았습니다.'
fi

set +e
touch "$fake_root/codex.invalid-score"
invalid_score_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
invalid_score_status=$?
set -e
rm -f "$fake_root/codex.invalid-score"
if [ "$invalid_score_status" -eq 0 ] || ! grep -Fq 'score 필드가 정확히 하나' <<< "$invalid_score_output"; then
  printf '%s\n' "$invalid_score_output" >&2
  fail '범위를 벗어난 score를 pre-push가 차단하지 않았습니다.'
fi

touch "$fake_root/codex.duplicate"
set +e
duplicate_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
duplicate_status=$?
set -e
rm -f "$fake_root/codex.duplicate"
if [ "$duplicate_status" -eq 0 ] || ! grep -Fq 'decision 필드가 정확히 하나' <<< "$duplicate_output"; then
  printf '%s\n' "$duplicate_output" >&2
  fail '중복된 구조화 decision 필드를 pre-push가 차단하지 않았습니다.'
fi

for duplicate_field in risk-score review-labels; do
  touch "$fake_root/codex.duplicate-$duplicate_field"
  set +e
  duplicate_field_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
    | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
        JDSNACK_REVIEW_BASE_REF="$base_ref" \
        bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
  duplicate_field_status=$?
  set -e
  rm -f "$fake_root/codex.duplicate-$duplicate_field"
  if [ "$duplicate_field_status" -eq 0 ] || ! grep -Fq "${duplicate_field//-/_} 필드가 정확히 하나" <<< "$duplicate_field_output"; then
    printf '%s\n' "$duplicate_field_output" >&2
    fail "중복된 ${duplicate_field//-/_} 필드를 pre-push가 차단하지 않았습니다."
  fi
done

touch "$fake_root/codex.malformed-findings"
set +e
malformed_findings_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
malformed_findings_status=$?
set -e
rm -f "$fake_root/codex.malformed-findings"
if [ "$malformed_findings_status" -eq 0 ] || ! grep -Fq 'findings는' <<< "$malformed_findings_output"; then
  printf '%s\n' "$malformed_findings_output" >&2
  fail '비정형 findings 항목을 pre-push가 차단하지 않았습니다.'
fi

set +e
touch "$fake_root/codex.failure"
reviewer_failure_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
reviewer_failure_status=$?
set -e
rm -f "$fake_root/codex.failure"
if [ "$reviewer_failure_status" -eq 0 ] || ! grep -Fq '리뷰를 완료하지 못했습니다' <<< "$reviewer_failure_output"; then
  printf '%s\n' "$reviewer_failure_output" >&2
  fail 'Codex reviewer 실패 경로가 제한된 PATH에서도 hook 도구를 사용할 수 없습니다.'
fi

set +e
head_mismatch_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$base_sha" "$base_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
head_mismatch_status=$?
set -e
if [ "$head_mismatch_status" -eq 0 ] || ! grep -Fq '현재 checkout의 HEAD와' <<< "$head_mismatch_output"; then
  printf '%s\n' "$head_mismatch_output" >&2
  fail 'push head와 local HEAD 불일치를 pre-push가 차단하지 않았습니다.'
fi

rm -f "$fake_root/codex.invoked"
set +e
destination_ref_mismatch_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/main %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
destination_ref_mismatch_status=$?
set -e
if [ "$destination_ref_mismatch_status" -eq 0 ] || ! grep -Fq 'destination ref가 현재 checkout 브랜치' <<< "$destination_ref_mismatch_output"; then
  printf '%s\n' "$destination_ref_mismatch_output" >&2
  fail '현재 브랜치가 아닌 원격 destination ref push를 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail '원격 destination ref 불일치가 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

rm -f "$fake_root/codex.invoked"
set +e
source_ref_mismatch_output="$(printf 'refs/heads/codex/unreviewed %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
source_ref_mismatch_status=$?
set -e
if [ "$source_ref_mismatch_status" -eq 0 ] || ! grep -Fq 'local ref가 현재 checkout 브랜치' <<< "$source_ref_mismatch_output"; then
  printf '%s\n' "$source_ref_mismatch_output" >&2
  fail '현재 브랜치가 아닌 local ref push를 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail 'local ref 불일치가 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

touch "$fake_root/codex.bad-risk"
set +e
bad_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
bad_status=$?
set -e
rm -f "$fake_root/codex.bad-risk"
if [ "$bad_status" -eq 0 ] || ! grep -Fq 'push를 차단합니다' <<< "$bad_output"; then
  printf '%s\n' "$bad_output" >&2
  fail '불일치한 위험도 결과를 pre-push가 차단하지 않았습니다.'
fi

set +e
touch "$fake_root/codex.blocking"
blocking_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
blocking_status=$?
set -e
rm -f "$fake_root/codex.blocking"
if [ "$blocking_status" -eq 0 ] || ! grep -Fq 'blocker/major 또는 P0/P1' <<< "$blocking_output"; then
  printf '%s\n' "$blocking_output" >&2
  fail 'blocker/P1 findings를 pre-push가 차단하지 않았습니다.'
fi

set +e
multi_output="$(printf 'refs/heads/codex/one %s refs/remotes/origin/one %s\nrefs/heads/codex/two %s refs/remotes/origin/two %s\n' "$head_sha" "$head_sha" "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project) 2>&1)"
multi_status=$?
set -e
if [ "$multi_status" -eq 0 ] || ! grep -Fq '여러 ref가 한 번에 push되어' <<< "$multi_output"; then
  printf '%s\n' "$multi_output" >&2
  fail '다중 ref push를 pre-push가 차단하지 않았습니다.'
fi

printf '\ndelete-only dirty fixture\n' >> "$test_worktree/scripts/README.md"
rm -f "$fake_root/codex.invoked"
set +e
delete_only_output="$(
  cd "$test_worktree"
  printf 'refs/heads/codex/pre-push-test 0000000000000000000000000000000000000000 refs/heads/codex/pre-push-test %s\n' "$head_sha" \
    | PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project 2>&1
)"
delete_only_status=$?
set -e
if [ "$delete_only_status" -eq 0 ] || ! grep -Fq 'Codex 리뷰 전에 staged·working-tree 변경' <<< "$delete_only_output"; then
  printf '%s\n' "$delete_only_output" >&2
  fail '삭제 ref 전용 push에서도 dirty checkout을 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail '삭제 ref 전용 dirty checkout이 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

printf '\npre-push tracked fixture\n' >> "$test_worktree/scripts/README.md"
rm -f "$fake_root/codex.invoked"
set +e
tracked_output="$(
  cd "$test_worktree"
  printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" '0000000000000000000000000000000000000000' \
    | PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://github.com/silverThunder09/jdsnack-agent-os-project 2>&1
)"
tracked_status=$?
set -e
if [ "$tracked_status" -eq 0 ] || ! grep -Fq 'tracked checkout 상태가 다릅니다' <<< "$tracked_output"; then
  printf '%s\n' "$tracked_output" >&2
  fail 'tracked dirty checkout을 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail 'tracked dirty checkout이 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

echo 'Pre-push AI review contract tests passed'
