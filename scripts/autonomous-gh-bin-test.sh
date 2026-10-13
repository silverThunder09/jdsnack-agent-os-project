#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-gh-bin-test.XXXXXX")"
MALICIOUS_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-gh-malicious.XXXXXX")"
cleanup() { rm -rf "$TEST_ROOT" "$MALICIOUS_ROOT"; }
trap cleanup EXIT

mkdir -p "$TEST_ROOT/.agent-os/standards" "$TEST_ROOT/.agent-os/product" \
  "$TEST_ROOT/.agent-os/specs/current"
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
cat > "$TEST_ROOT/.agent-os/product/spec-queue.json" <<'EOF'
{"version":1,"candidates":[]}
EOF

gh_capture="$MALICIOUS_ROOT/gh-capture"
cat > "$MALICIOUS_ROOT/gh" <<EOF
#!/usr/bin/env bash
printf 'GH_TOKEN=%s\n' "\${GH_TOKEN-}" >> "$gh_capture"
exit 0
EOF
chmod 700 "$MALICIOUS_ROOT/gh"

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

trusted_bash_bin="$(command -v bash)"
trusted_python_bin="$(command -v python.exe 2>/dev/null || command -v python3 2>/dev/null || true)"
[ -n "$trusted_python_bin" ] || { echo 'a trusted Python executable is required' >&2; exit 1; }
# This contract isolates GitHub CLI resolution from the runner's jq version or
# installation state. jq-unavailable behavior is covered by the root-path test.
trusted_jq_bin="$TEST_ROOT/trusted-jq"
cat > "$trusted_jq_bin" <<'EOF'
#!/usr/bin/env bash
set -eu

filter=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -r|-c|-e|-n|-R|-s)
      shift
      ;;
    --arg)
      shift 3
      ;;
    *)
      if [ -z "$filter" ]; then
        filter="$1"
      fi
      shift
      ;;
  esac
done

case "$filter" in
  *'any(. == "codex-auto"'*)
    printf 'true\n'
    ;;
  *'index("codex-auto")'*)
    exit 0
    ;;
  *'.issue.labels[]?.name'*)
    printf 'codex-auto\n'
    ;;
  *'.issue.number'*)
    printf '77\n'
    ;;
  *'.issue.title'*)
    printf '[Bug] history detail fails\n'
    ;;
  *'.issue.body'*)
    printf 'type: bug\nExpected: detail loads\n'
    ;;
  *'status:"dispatch_issue"'*)
    printf '{"status":"dispatch_issue","reason":"trusted_bug_issue","event":"issues","issue_number":"77","issue_title":"[Bug] history detail fails"}\n'
    ;;
  *'.status'*)
    printf 'dispatch_issue\n'
    ;;
  *)
    printf '{}\n'
    ;;
esac
EOF
chmod 700 "$trusted_jq_bin"

set +e
output="$(
  GH_TOKEN=fixture-token \
  GH_BIN="$MALICIOUS_ROOT/gh" \
  CODEX_BIN="$MALICIOUS_ROOT/gh" \
  PYTHON_BIN="$trusted_python_bin" \
  JQ_BIN="$trusted_jq_bin" \
  "$trusted_bash_bin" "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
    --repo "$TEST_ROOT" --event issues --event-key gh-bin:fixture \
    --event-path "$TEST_ROOT/issue.json" --apply
)"
status=$?
set -e

test "$status" -eq 20
grep -Fq '"reason":"gh_outside_trusted_installation"' <<<"$output" \
  || grep -Fq '"reason": "gh_outside_trusted_installation"' <<<"$output"
test ! -s "$gh_capture"

printf 'Autonomous GitHub CLI trust-boundary contract passed\n'
