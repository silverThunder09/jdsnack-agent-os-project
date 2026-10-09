#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-autonomous-loop-test.XXXXXX")"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

mkdir -p "$TEST_ROOT/.agent-os/standards" "$TEST_ROOT/.agent-os/product" "$TEST_ROOT/.agent-os/specs/current"
cat > "$TEST_ROOT/.agent-os/standards/index.yml" <<'EOF'
active_specs:
  - .agent-os/specs/current
EOF
cat > "$TEST_ROOT/.agent-os/specs/current/plan.md" <<'EOF'
# Plan
- 구현 상태: `completed`

### T1. First
- 상태: `completed`
EOF
cp "$ROOT_DIR/.agent-os/product/spec-queue.json" "$TEST_ROOT/.agent-os/product/spec-queue.json"

mkdir -p "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/python3" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"status":"idle"}'
EOF
chmod +x "$TEST_ROOT/bin/python3"

set +e
missing_jq_output="$(
  PATH="$TEST_ROOT/bin:$PATH" \
  JQ_BIN=missing-jq \
  bash "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
    --repo "$TEST_ROOT" --event push --event-key missing-jq
)"
missing_jq_code=$?
set -e
test "$missing_jq_code" -eq 20
grep -q '"status":"needs_human"' <<<"$missing_jq_output"
grep -q '"reason":"jq_unavailable"' <<<"$missing_jq_output"

# A queue awaiting a product signal must stop work without failing CI.
printf 'active_specs: []\n' > "$TEST_ROOT/.agent-os/standards/index.yml"
cat > "$TEST_ROOT/.agent-os/product/spec-queue.json" <<'EOF'
{"version":1,"candidates":[{
  "id":"next-feature","slug":"next-feature","title":"Next Feature",
  "priority":1,"status":"candidate","auto_promote":true,
  "start_condition":{"type":"issue_label","label":"product-signal:next"}
}]}
EOF
summary_path="$TEST_ROOT/step-summary.md"
set +e
waiting_output="$(SECURITY_BIN=missing-security GITHUB_STEP_SUMMARY="$summary_path" \
  JDSNACK_LOOP_EXECUTOR=fixture bash "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
    --repo "$TEST_ROOT" --event push --event-key waiting:fixture --apply)"
waiting_code=$?
set -e
printf 'Product-signal wait exit code: %s\n' "$waiting_code"
test "$waiting_code" -eq 0
grep -q '"status": "needs_human"' <<<"$waiting_output"
grep -q '"reason": "no_candidate_start_condition_satisfied"' <<<"$waiting_output"
grep -q '^::notice ' <<<"$waiting_output"
grep -q 'no_candidate_start_condition_satisfied' "$summary_path"
test ! -f "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
test ! -f "$TEST_ROOT/.agent-os/runtime/autonomous-loop-state.json"
test ! -d "$TEST_ROOT/.agent-os/runtime/.autonomous-loop.lock"

# A malformed state remains a failure rather than becoming an idle success.
printf 'invalid json\n' > "$TEST_ROOT/.agent-os/runtime/autonomous-loop-state.json"
set +e
invalid_output="$(SECURITY_BIN=missing-security JDSNACK_LOOP_EXECUTOR=fixture \
  bash "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
    --repo "$TEST_ROOT" --event push --event-key invalid:fixture --apply)"
invalid_code=$?
set -e
test "$invalid_code" -eq 20
grep -q '"reason":"loop_decision_failed"' <<<"$invalid_output"
test ! -f "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
rm "$TEST_ROOT/.agent-os/runtime/autonomous-loop-state.json"

# An unfinished active Feature with no ready ticket remains blocked.
printf 'active_specs:\n  - .agent-os/specs/current\n' > "$TEST_ROOT/.agent-os/standards/index.yml"
cp "$TEST_ROOT/.agent-os/specs/current/plan.md" "$TEST_ROOT/completed-plan.md"
sed 's/구현 상태: `completed`/구현 상태: `in-progress`/' \
  "$TEST_ROOT/completed-plan.md" > "$TEST_ROOT/.agent-os/specs/current/plan.md"
set +e
blocked_output="$(SECURITY_BIN=missing-security JDSNACK_LOOP_EXECUTOR=fixture \
  bash "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
    --repo "$TEST_ROOT" --event push --event-key blocked:fixture --apply)"
blocked_code=$?
set -e
test "$blocked_code" -eq 20
grep -q '"reason": "active_spec_has_no_ready_ticket"' <<<"$blocked_output"
test ! -f "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
cp "$TEST_ROOT/completed-plan.md" "$TEST_ROOT/.agent-os/specs/current/plan.md"

# Replace the production queue with a minimal deterministic fixture.
python3 - "$TEST_ROOT/.agent-os/product/spec-queue.json" <<'PY'
import json
import sys
path = sys.argv[1]
json.dump({"version": 1, "candidates": [{
  "id": "next-feature", "slug": "next-feature", "title": "Next Feature",
  "priority": 1, "status": "candidate", "auto_promote": True,
  "start_condition": {"type": "feature_completed", "feature": "current"}
}]}, open(path, "w"), indent=2)
PY

output="$(JDSNACK_LOOP_EXECUTOR=fixture bash "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
  --repo "$TEST_ROOT" --event push --event-key merge:fixture --apply)"
printf '%s\n' "$output"
test -f "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
grep -q '"status": "promote_spec"' "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"

cat > "$TEST_ROOT/issue.json" <<'EOF'
{
  "issue": {
    "number": 77,
    "title": "[Bug] history detail fails",
    "body": "type: bug\nExpected: detail loads",
    "labels": [{"name": "codex-auto"}]
  }
}
EOF
rm -f "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
issue_output="$(JDSNACK_LOOP_EXECUTOR=fixture bash "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
  --repo "$TEST_ROOT" --event issues --event-key issue:77 --event-path "$TEST_ROOT/issue.json" --apply)"
printf '%s\n' "$issue_output"
grep -q '"status": "dispatch_issue"' "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"

cat > "$TEST_ROOT/feature-issue.json" <<'EOF'
{
  "issue": {
    "number": 88,
    "title": "[Feature] export analysis report",
    "body": "type: feature\nAcceptance: user can export a report",
    "labels": [{"name": "codex-auto"}]
  }
}
EOF
rm -f "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
feature_output="$(JDSNACK_LOOP_EXECUTOR=fixture bash "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
  --repo "$TEST_ROOT" --event issues --event-key issue:88 --event-path "$TEST_ROOT/feature-issue.json" --apply)"
printf '%s\n' "$feature_output"
grep -q '"status": "promote_spec"' "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
! grep -q 'issue-88' "$TEST_ROOT/.agent-os/runtime/autonomous-loop-state.json"

printf 'Autonomous Spec loop tests passed\n'
