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
workspace_arg="$ROOT_DIR"
if command -v cygpath >/dev/null 2>&1; then
  workspace_arg="$(cygpath -w "$ROOT_DIR")"
fi
if ! risk_json="$($pwsh_bin -NoProfile -File "$workspace_arg/scripts/review-risk.ps1" -Workspace "$workspace_arg" -BaseSha "$base_sha" -HeadSha "$head_sha")"; then
  fail '위험도 계산기가 fixture의 base/head를 처리하지 못했습니다.'
fi
expected_risk="$(jq -r '.riskBand' <<< "$risk_json")"
expected_score="$(jq -r '.riskScore' <<< "$risk_json")"
expected_labels="$(jq -r '.reviewLabels | join(", ")' <<< "$risk_json")"

fake_root="$(mktemp -d)"
dirty_fixture="$ROOT_DIR/.codex-pre-push-dirty-$RANDOM"
cleanup() {
  rm -rf "$fake_root"
  rm -f "$dirty_fixture"
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
No unresolved findings.
review_summary:
Synthetic pre-push contract result.
EOF
FAKE_CODEX
chmod +x "$fake_root/codex"

run_review() {
  printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
    | PATH="$fake_root:$PATH" \
      JDSNACK_REVIEW_BASE_REF="$base_ref" \
      JDSNACK_FAKE_RISK="$expected_risk" \
      JDSNACK_FAKE_RISK_SCORE="$expected_score" \
      JDSNACK_FAKE_LABELS="$expected_labels" \
      bash "$ROOT_DIR/scripts/pre-push-ai-review.sh"
}

run_review >/dev/null

set +e
bad_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | PATH="$fake_root:$PATH" \
    JDSNACK_REVIEW_BASE_REF="$base_ref" \
    JDSNACK_FAKE_RISK='Light' \
    JDSNACK_FAKE_RISK_SCORE="$expected_score" \
    JDSNACK_FAKE_LABELS="$expected_labels" \
    bash "$ROOT_DIR/scripts/pre-push-ai-review.sh" 2>&1)"
bad_status=$?
set -e
if [ "$bad_status" -eq 0 ] || ! grep -Fq 'push를 차단합니다' <<< "$bad_output"; then
  printf '%s\n' "$bad_output" >&2
  fail '불일치한 위험도 결과를 pre-push가 차단하지 않았습니다.'
fi

set +e
multi_output="$(printf 'refs/heads/codex/one %s refs/remotes/origin/one %s\nrefs/heads/codex/two %s refs/remotes/origin/two %s\n' "$head_sha" "$head_sha" "$head_sha" "$head_sha" \
  | PATH="$fake_root:$PATH" \
    JDSNACK_REVIEW_BASE_REF="$base_ref" \
    JDSNACK_FAKE_RISK="$expected_risk" \
    JDSNACK_FAKE_RISK_SCORE="$expected_score" \
    JDSNACK_FAKE_LABELS="$expected_labels" \
    bash "$ROOT_DIR/scripts/pre-push-ai-review.sh" 2>&1)"
multi_status=$?
set -e
if [ "$multi_status" -eq 0 ] || ! grep -Fq '여러 ref가 한 번에 push되어' <<< "$multi_output"; then
  printf '%s\n' "$multi_output" >&2
  fail '다중 ref push를 pre-push가 차단하지 않았습니다.'
fi

touch "$dirty_fixture"
set +e
dirty_output="$(printf 'refs/heads/codex/pre-push-test %s refs/heads/codex/pre-push-test %s\n' "$head_sha" "$head_sha" \
  | PATH="$fake_root:$PATH" \
    JDSNACK_REVIEW_BASE_REF="$base_ref" \
    JDSNACK_FAKE_RISK="$expected_risk" \
    JDSNACK_FAKE_RISK_SCORE="$expected_score" \
    JDSNACK_FAKE_LABELS="$expected_labels" \
    bash "$ROOT_DIR/scripts/pre-push-ai-review.sh" 2>&1)"
dirty_status=$?
set -e
rm -f "$dirty_fixture"
if [ "$dirty_status" -eq 0 ] || ! grep -Fq 'checkout 상태가 다릅니다' <<< "$dirty_output"; then
  printf '%s\n' "$dirty_output" >&2
  fail 'dirty checkout을 pre-push가 차단하지 않았습니다.'
fi

echo 'Pre-push AI review contract tests passed'
