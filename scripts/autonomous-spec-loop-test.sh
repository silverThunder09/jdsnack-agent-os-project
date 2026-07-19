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
