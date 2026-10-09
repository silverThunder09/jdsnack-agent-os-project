#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
canonical_origin_url='https://github.com/silverThunder09/jdsnack-agent-os-project'
fixture_root="$(mktemp -d)"
test_repo="$fixture_root/empty-diff-repo"
fake_bin="$fixture_root/bin"
fake_codex_home="$fixture_root/codex-home"

cleanup() {
  rm -rf "$fixture_root"
}
trap cleanup EXIT

mkdir -p "$fake_bin" "$fake_codex_home"
base_sha="$(git -C "$ROOT_DIR" rev-parse --verify 'origin/main^{commit}')"
git clone --quiet --no-checkout "$ROOT_DIR" "$test_repo"
git -C "$test_repo" checkout --quiet -B codex/pre-push-empty-diff "$base_sha"
git -C "$test_repo" remote set-url origin "$canonical_origin_url"
git -C "$test_repo" update-ref refs/remotes/origin/main "$base_sha"
cat > "$fake_bin/codex" <<'FAKE_CODEX'
#!/bin/sh
printf '%s\n' invoked > "${0%/*}/invoked"
exit 97
FAKE_CODEX
chmod +x "$fake_bin/codex"

set +e
empty_diff_output="$(
  cd "$test_repo"
  printf 'refs/heads/codex/pre-push-empty-diff %s refs/heads/codex/pre-push-empty-diff %s\n' \
    "$base_sha" '0000000000000000000000000000000000000000' \
    | PATH="$fake_bin:$PATH" \
      CODEX_HOME="$fake_codex_home" \
      JDSNACK_REVIEW_BASE_REF=origin/main \
      bash "$ROOT_DIR/scripts/pre-push-ai-review.sh" origin "$canonical_origin_url" 2>&1
)"
empty_diff_status=$?
set -e

if [ "$empty_diff_status" -eq 0 ] || ! grep -Fq 'branch diff가 비어' <<< "$empty_diff_output"; then
  printf '%s\n' "$empty_diff_output" >&2
  if [ -e "$fake_bin/invoked" ]; then
    echo 'Codex reviewer was invoked for an empty branch diff.' >&2
  fi
  echo 'pre-push did not reject an empty branch diff before review.' >&2
  exit 1
fi
if [ -e "$fake_bin/invoked" ]; then
  echo 'Codex reviewer was invoked before the empty branch diff was rejected.' >&2
  exit 1
fi

echo 'Pre-push empty-diff contract passed'
