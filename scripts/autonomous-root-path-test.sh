#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-autonomous-root-path.XXXXXX")"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT HUP INT TERM

trusted_bash_bin="$(command -v bash)"
trusted_dirname_bin="$(command -v dirname)"
capture="$TEST_ROOT/dirname-capture"
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/repo"

cat > "$TEST_ROOT/bin/dirname" <<EOF
#!$trusted_bash_bin
printf 'dirname-received-token=%s\n' "\${GH_TOKEN-}" >> "$capture"
exec "$trusted_dirname_bin" "\$@"
EOF
chmod 700 "$TEST_ROOT/bin/dirname"

set +e
PATH="$TEST_ROOT/bin:$PATH" \
GH_TOKEN=fixture-token \
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

printf 'Autonomous root path token boundary contract passed\n'
