#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-autonomous-root-path.XXXXXX")"
MALICIOUS_JQ_ROOT="$(mktemp -d "$ROOT_DIR/../jdsnack-jq-malicious.XXXXXX")"
cleanup() { rm -rf "$TEST_ROOT" "$MALICIOUS_JQ_ROOT"; }
trap cleanup EXIT HUP INT TERM

trusted_bash_bin="$(command -v bash)"
trusted_dirname_bin="$(command -v dirname)"
trusted_python_bin="$(command -v python.exe 2>/dev/null || command -v python3 2>/dev/null || true)"
[ -n "$trusted_python_bin" ] || { echo 'a trusted Python executable is required' >&2; exit 1; }
capture="$TEST_ROOT/dirname-capture"
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/repo"

cat > "$TEST_ROOT/bin/dirname" <<EOF
#!$trusted_bash_bin
printf 'dirname-received-token=%s\n' "\${GH_TOKEN-}" >> "$capture"
exec "$trusted_dirname_bin" "\$@"
EOF
chmod 700 "$TEST_ROOT/bin/dirname"

cat > "$MALICIOUS_JQ_ROOT/jq" <<EOF
#!$trusted_bash_bin
printf 'jq-received-token=%s\n' "\${GH_TOKEN-}" >> "$MALICIOUS_JQ_ROOT/capture"
exit 0
EOF
chmod 700 "$MALICIOUS_JQ_ROOT/jq"

set +e
PATH="$TEST_ROOT/bin:$PATH" \
GH_TOKEN=fixture-token \
PYTHON_BIN="$trusted_python_bin" \
JQ_BIN=missing-jq \
"$trusted_bash_bin" "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
  --repo "$TEST_ROOT/repo" --event push --event-key root-path
status=$?
set -e

test "$status" -eq 20
if [ -f "$capture" ] && grep -Fq -- 'fixture-token' "$capture"; then
  printf 'FAIL: pre-initialization dirname received GH_TOKEN\n' >&2
  exit 1
fi

set +e
jq_output="$(
  GH_TOKEN=fixture-token \
  PYTHON_BIN="$trusted_python_bin" \
  JQ_BIN="$MALICIOUS_JQ_ROOT/jq" \
  "$trusted_bash_bin" "$ROOT_DIR/scripts/autonomous-spec-loop.sh" \
    --repo "$TEST_ROOT/repo" --event push --event-key jq-path 2>&1
)"
jq_status=$?
set -e

test "$jq_status" -eq 20
grep -Fq '"reason":"jq_outside_trusted_installation"' <<<"$jq_output"
test ! -s "$MALICIOUS_JQ_ROOT/capture"

printf 'Autonomous root path token boundary contract passed\n'
