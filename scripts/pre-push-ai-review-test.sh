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
fake_root="$(mktemp -d)"
fixture_root="$(mktemp -d)"
test_worktree="$fixture_root/test-worktree"
git worktree add --detach "$test_worktree" "$head_sha" >/dev/null
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
export JDSNACK_TEST_SECRET_TOKEN='must-be-cleared-before-review'
export JDSNACK_TEST_CUSTOM='must-be-cleared-by-allowlist'

printf '%s\n' "$expected_risk" > "$fake_root/expected-risk"
printf '%s\n' "$expected_score" > "$fake_root/expected-risk-score"
printf '%s\n' "$expected_labels" > "$fake_root/expected-labels"

cleanup() {
  if [ -d "$test_worktree" ]; then
    git worktree remove --force "$test_worktree" >/dev/null 2>&1 || true
  fi
  rm -rf "$fake_root"
  rm -rf "$fixture_root"
}
trap cleanup EXIT

cat > "$fake_root/codex" <<'FAKE_CODEX'
#!/bin/sh
set -eu

fixture_dir='__FAKE_ROOT__'
output_path=""
help_requested=0
network_config_seen=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help)
      help_requested=1
      ;;
    --config)
      shift
      if [ "${1:-}" = 'sandbox_workspace_write.network_access=false' ]; then
        network_config_seen=1
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
esac
[ "$help_requested" -eq 1 ] && exit 0
[ -n "$output_path" ] || exit 2
[ "$network_config_seen" -eq 1 ] || exit 9
case "${PATH-}" in
  */reviewer-bin) ;;
  *) exit 3 ;;
esac
if command -v git >/dev/null 2>&1; then
  exit 4
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
case "${PWD-}" in
  *test-worktree*) exit 12 ;;
esac
case "${CODEX_HOME-}" in
  *codex-home*) ;;
  *) exit 10 ;;
esac
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
    printf '%s\n' '- correctness: PASS — the reviewed diff has a coherent implementation.'
    printf '%s\n' '- contract: PASS — the requested workflow contracts are covered.'
    printf '%s\n' '- tests: PASS — executable contract tests cover the changed paths.'
    printf '%s\n' '- security: PASS — restricted execution and fail-closed checks are preserved.'
    printf '%s\n' '- maintainability: PASS — the change keeps validation responsibilities explicit.'
    printf '%s\n' "- score rationale: ${fake_score}/5 — all five rubric items have concrete passing evidence."
    printf '%s\n' '- conclusion: the reviewed change is safe and complete for this push.'
  fi
} >> "$output_path"
FAKE_CODEX
sed -i "s|__FAKE_ROOT__|$fake_root|g" "$fake_root/codex"
chmod +x "$fake_root/codex"
if [ -n "$test_cygpath_bin" ]; then
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$test_cygpath_bin" > "$fake_root/cygpath"
  chmod +x "$fake_root/cygpath"
fi

run_review() {
  (
    cd "$test_worktree"
    printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
      | PATH="$fake_root:$PATH" \
        JDSNACK_REVIEW_BASE_REF="$base_ref" \
        bash "$test_worktree/.githooks/pre-push" origin https://example.invalid
  )
}

run_review >/dev/null

if [ ! -e "$fake_root/copied-entry-invoked" ]; then
  fail 'Codex reviewer가 원본 실행 파일이 아닌 전용 reviewer entrypoint를 사용하지 않았습니다.'
fi

rm -f "$fake_root/codex.invoked"
set +e
tag_output="$(printf 'refs/tags/v1.0.0 %s refs/tags/v1.0.0 %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
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
      bash "$test_worktree/scripts/pre-push-ai-review.sh" upstream https://example.invalid) 2>&1)"
remote_status=$?
set -e
if [ "$remote_status" -eq 0 ] || ! grep -Fq 'remote는 origin으로 고정' <<< "$remote_output"; then
  printf '%s\n' "$remote_output" >&2
  fail 'origin 이외 remote push를 pre-push가 차단하지 않았습니다.'
fi
if [ -e "$fake_root/codex.invoked" ]; then
  fail 'origin 이외 remote push가 Codex reviewer 실행 전에 차단되지 않았습니다.'
fi

touch "$fake_root/codex.weak-summary"
set +e
weak_summary_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
weak_summary_status=$?
set -e
rm -f "$fake_root/codex.weak-summary"
if [ "$weak_summary_status" -eq 0 ] || ! grep -Fq '5개 rubric' <<< "$weak_summary_output"; then
  printf '%s\n' "$weak_summary_output" >&2
  fail '실질적인 rubric 근거가 없는 review_summary를 pre-push가 차단하지 않았습니다.'
fi

set +e
touch "$fake_root/codex.invalid-score"
invalid_score_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
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
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
duplicate_status=$?
set -e
rm -f "$fake_root/codex.duplicate"
if [ "$duplicate_status" -eq 0 ] || ! grep -Fq 'decision 필드가 정확히 하나' <<< "$duplicate_output"; then
  printf '%s\n' "$duplicate_output" >&2
  fail '중복된 구조화 decision 필드를 pre-push가 차단하지 않았습니다.'
fi

touch "$fake_root/codex.malformed-findings"
set +e
malformed_findings_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
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
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
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
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
head_mismatch_status=$?
set -e
if [ "$head_mismatch_status" -eq 0 ] || ! grep -Fq '현재 checkout의 HEAD와' <<< "$head_mismatch_output"; then
  printf '%s\n' "$head_mismatch_output" >&2
  fail 'push head와 local HEAD 불일치를 pre-push가 차단하지 않았습니다.'
fi

touch "$fake_root/codex.bad-risk"
set +e
bad_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
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
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
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
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid) 2>&1)"
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
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid 2>&1
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
  printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
    | PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" origin https://example.invalid 2>&1
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
