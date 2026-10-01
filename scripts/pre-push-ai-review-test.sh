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

output_path=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output-last-message)
      shift
      output_path="${1:-}"
      ;;
  esac
  shift
done

[ -n "$output_path" ] || exit 2
if command -v cygpath >/dev/null 2>&1 && printf '%s' "$output_path" | grep -Eq '^[A-Za-z]:\\'; then
  output_path="$(cygpath -u "$output_path")"
fi

cat > "$output_path" <<EOF
decision: ${JDSNACK_FAKE_DECISION:-PASS}
score: ${JDSNACK_FAKE_SCORE:-5}
risk: ${JDSNACK_FAKE_RISK}
risk_score: ${JDSNACK_FAKE_RISK_SCORE}
review_labels: ${JDSNACK_FAKE_LABELS}
findings:
EOF
if [ -f "$0.blocking" ]; then
  printf '%s\n' '- P1 — synthetic blocker' >> "$output_path"
else
  printf '%s\n' '- none' >> "$output_path"
fi
cat >> "$output_path" <<EOF
review_summary:
Synthetic pre-push contract result.
EOF
FAKE_CODEX
chmod +x "$fake_root/codex"

run_review() {
  (
    cd "$test_worktree"
    printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
      | PATH="$fake_root:$PATH" \
        JDSNACK_REVIEW_BASE_REF="$base_ref" \
        JDSNACK_FAKE_RISK="$expected_risk" \
        JDSNACK_FAKE_RISK_SCORE="$expected_score" \
        JDSNACK_FAKE_LABELS="$expected_labels" \
        bash "$test_worktree/scripts/pre-push-ai-review.sh"
  )
}

run_review >/dev/null

set +e
head_mismatch_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$base_sha" "$base_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      JDSNACK_FAKE_RISK="$expected_risk" \
      JDSNACK_FAKE_RISK_SCORE="$expected_score" \
      JDSNACK_FAKE_LABELS="$expected_labels" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh") 2>&1)"
head_mismatch_status=$?
set -e
if [ "$head_mismatch_status" -eq 0 ] || ! grep -Fq '현재 checkout의 HEAD와' <<< "$head_mismatch_output"; then
  printf '%s\n' "$head_mismatch_output" >&2
  fail 'push head와 local HEAD 불일치를 pre-push가 차단하지 않았습니다.'
fi

set +e
bad_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      JDSNACK_FAKE_RISK='Light' \
      JDSNACK_FAKE_RISK_SCORE="$expected_score" \
      JDSNACK_FAKE_LABELS="$expected_labels" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh") 2>&1)"
bad_status=$?
set -e
if [ "$bad_status" -eq 0 ] || ! grep -Fq 'push를 차단합니다' <<< "$bad_output"; then
  printf '%s\n' "$bad_output" >&2
  fail '불일치한 위험도 결과를 pre-push가 차단하지 않았습니다.'
fi

set +e
touch "$fake_root/codex.blocking"
blocking_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | (cd "$test_worktree" && PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      JDSNACK_FAKE_RISK="$expected_risk" \
      JDSNACK_FAKE_RISK_SCORE="$expected_score" \
      JDSNACK_FAKE_LABELS="$expected_labels" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh") 2>&1)"
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
      JDSNACK_FAKE_RISK="$expected_risk" \
      JDSNACK_FAKE_RISK_SCORE="$expected_score" \
      JDSNACK_FAKE_LABELS="$expected_labels" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh") 2>&1)"
multi_status=$?
set -e
if [ "$multi_status" -eq 0 ] || ! grep -Fq '여러 ref가 한 번에 push되어' <<< "$multi_output"; then
  printf '%s\n' "$multi_output" >&2
  fail '다중 ref push를 pre-push가 차단하지 않았습니다.'
fi

printf '\npre-push tracked fixture\n' >> "$test_worktree/scripts/README.md"
set +e
tracked_output="$(
  cd "$test_worktree"
  printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
    | PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      JDSNACK_FAKE_RISK="$expected_risk" \
      JDSNACK_FAKE_RISK_SCORE="$expected_score" \
      JDSNACK_FAKE_LABELS="$expected_labels" \
      bash "$test_worktree/scripts/pre-push-ai-review.sh" 2>&1
)"
tracked_status=$?
set -e
if [ "$tracked_status" -eq 0 ] || ! grep -Fq 'tracked checkout 상태가 다릅니다' <<< "$tracked_output"; then
  printf '%s\n' "$tracked_output" >&2
  fail 'tracked dirty checkout을 pre-push가 차단하지 않았습니다.'
fi

echo 'Pre-push AI review contract tests passed'
