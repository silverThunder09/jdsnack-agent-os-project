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
helper_log="$TEST_ROOT/helper.log"
bash_log="$TEST_ROOT/bash.log"
trusted_bash_bin="$(command -v bash)"
trusted_python_bin="$(command -v python.exe 2>/dev/null || command -v python3 2>/dev/null || true)"
[ -n "$trusted_python_bin" ] || { echo 'a trusted Python executable is required' >&2; exit 1; }
export PYTHON_BIN="$trusted_python_bin"

cat > "$TEST_ROOT/bin/python3" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"status":"idle"}'
EOF
chmod +x "$TEST_ROOT/bin/python3"

cat > "$TEST_ROOT/bin/mktemp" <<EOF
#!$trusted_bash_bin
printf 'mktemp-received-token=%s\n' "\${GH_TOKEN-}" >> "$helper_log"
exit 91
EOF
chmod +x "$TEST_ROOT/bin/mktemp"

cat > "$TEST_ROOT/bin/mkdir" <<EOF
#!$trusted_bash_bin
printf 'mkdir-received-token=%s\n' "\${GH_TOKEN-}" >> "$helper_log"
exit 92
EOF
chmod +x "$TEST_ROOT/bin/mkdir"

trusted_jq_bin="$(command -v jq)"
cat > "$TEST_ROOT/bin/jq" <<EOF
#!$trusted_bash_bin
printf 'jq-received-token=%s\n' "\${GH_TOKEN-}" >> "$helper_log"
exec "$trusted_jq_bin" "\$@"
EOF
chmod +x "$TEST_ROOT/bin/jq"

cat > "$TEST_ROOT/bin/bash" <<EOF
#!$trusted_bash_bin
printf 'bash-received-token=%s\n' "\${GH_TOKEN-}" >> "$bash_log"
exec "$trusted_bash_bin" "\$@"
EOF
chmod +x "$TEST_ROOT/bin/bash"

set +e
missing_jq_output="$(
  PATH="$TEST_ROOT/bin:$PATH" \
  JQ_BIN=missing-jq \
  "$trusted_bash_bin" "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
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
# The first PATH entry contains a Bash wrapper that would capture GH_TOKEN if
# the loop resolved Bash from the mutable environment. The loop must use its
# trusted fixed-path Bash instead.
set +e
bash_path_output="$(PATH="$TEST_ROOT/bin:$PATH" GH_TOKEN=fixture-token SECURITY_BIN=missing-security GITHUB_STEP_SUMMARY="$summary_path" \
  JDSNACK_LOOP_EXECUTOR=fixture "$trusted_bash_bin" "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
    --repo "$TEST_ROOT" --event push --event-key bash:fixture --apply)"
bash_path_code=$?
set -e
printf 'PATH-prepended Bash exit code: %s\n' "$bash_path_code"
test "$bash_path_code" -eq 0
grep -q '"status": "needs_human"' <<<"$bash_path_output"
test ! -e "$bash_log"

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

# A worktree creation failure before Git registration must not leave the loop lock.
failure_root="$TEST_ROOT/worktree-failure"
mkdir -p "$failure_root/.agent-os/standards" "$failure_root/.agent-os/product" "$failure_root/.agent-os/specs/current"
cat > "$failure_root/.agent-os/standards/index.yml" <<'EOF'
active_specs:
  - .agent-os/specs/current
EOF
cp "$TEST_ROOT/.agent-os/specs/current/plan.md" "$failure_root/.agent-os/specs/current/plan.md"
cat > "$failure_root/.agent-os/product/spec-queue.json" <<'EOF'
{"version":1,"candidates":[{
  "id":"worktree-failure","slug":"worktree-failure","title":"Worktree failure",
  "priority":1,"status":"candidate","auto_promote":true,
  "start_condition":{"type":"feature_completed","feature":"current"}
}]}
EOF
"$(command -v git)" -C "$failure_root" init -q
git -C "$failure_root" config extensions.worktreeConfig true
git -C "$failure_root" config --worktree core.fsmonitor '!printf unsafe-worktree'
set +e
worktree_config_output="$(JQ_BIN="$trusted_jq_bin" PYTHON_BIN="$trusted_python_bin" "$trusted_bash_bin" "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
  --repo "$failure_root" --event push --event-key unsafe-worktree:fixture 2>&1)"
worktree_config_code=$?
set -e
test "$worktree_config_code" -eq 20
grep -q '"reason":"unsafe_worktree_git_config_core.fsmonitor"' <<<"$worktree_config_output"
git -C "$failure_root" config --worktree --unset core.fsmonitor
set +e
failure_output="$(SECURITY_BIN=missing-security "$trusted_bash_bin" "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
  --repo "$failure_root" --event push --event-key worktree-failure:fixture --apply)"
failure_code=$?
set -e
printf 'Worktree creation failure exit code: %s\n' "$failure_code"
test "$failure_code" -eq 20
test ! -d "$failure_root/.agent-os/runtime/.autonomous-loop.lock"
test -z "$(find "$failure_root/.agent-os/runtime" -mindepth 1 -maxdepth 1 -type d -name 'jdsnack-*' -print -quit)"

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
"${PYTHON_BIN:-python3}" - "$TEST_ROOT/.agent-os/product/spec-queue.json" <<'PY'
import json
import sys
path = sys.argv[1]
json.dump({"version": 1, "candidates": [{
  "id": "next-feature", "slug": "next-feature", "title": "Next Feature",
  "priority": 1, "status": "candidate", "auto_promote": True,
  "start_condition": {"type": "feature_completed", "feature": "current"}
}]}, open(path, "w"), indent=2)
PY

output="$(PATH="$TEST_ROOT/bin:$PATH" GH_TOKEN=fixture-token JQ_BIN="$TEST_ROOT/bin/jq" JDSNACK_LOOP_EXECUTOR=fixture "$trusted_bash_bin" "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
  --repo "$TEST_ROOT" --event push --event-key merge:fixture --apply)"
printf '%s\n' "$output"
test -f "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
grep -q '"status": "promote_spec"' "$TEST_ROOT/.agent-os/runtime/last-fixture-dispatch.json"
test -f "$helper_log"
! grep -Fq 'fixture-token' "$helper_log"

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
