#!/usr/bin/env bash
set -euo pipefail

workspace="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="${JDSNACK_HOOK_TEST_TMPDIR:-$workspace}"
if [ -z "${JDSNACK_HOOK_TEST_TMPDIR-}" ] && [ -n "${LOCALAPPDATA-}" ] && command -v cygpath >/dev/null 2>&1; then
  test_root="$(cygpath -u "$LOCALAPPDATA")"
fi
temporary="$(mktemp -d "$test_root/.trusted-hook-fixture.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT
fixture="$temporary/repo"
mkdir -p "$fixture"
sources='scripts/trusted-hooks/pre-commit scripts/trusted-hooks/pre-push scripts/trusted-hooks/verify-hook-bundle.py scripts/trusted-hooks/render-reviewer.py scripts/trusted-hooks/verify-trusted-hook-bundle-acl.ps1 scripts/check-ai-readiness.py backends.json scripts/pre-push-ai-review.sh scripts/review-policy.json scripts/review-risk.ps1 scripts/secure-review-temp-acl.ps1 scripts/verify-codex-auth-permissions.ps1 scripts/codex-auth-permissions.ps1 scripts/review-path-safety.ps1 scripts/install-git-hooks.sh'
for source in $sources; do
  mkdir -p "$fixture/$(dirname "$source")"
  cp "$workspace/$source" "$fixture/$source"
done
cd "$fixture"
git init -q
git config user.name 'Trusted Hook Fixture'
git config user.email 'trusted-hooks@example.invalid'
git add .
git commit -qm 'fixture: trusted main sources'
git branch -M main
main_sha="$(git rev-parse HEAD)"
git update-ref refs/remotes/origin/main "$main_sha"
git switch -qc feature/tampered

mkdir -p .githooks
printf '%s\n' 'UNTRUSTED CHECKOUT HOOK' > .githooks/pre-push
printf '%s\n' 'UNTRUSTED REVIEWER' > scripts/pre-push-ai-review.sh
printf '%s\n' 'UNTRUSTED INSTALLER' > scripts/install-git-hooks.sh
printf '%s\n' 'UNTRUSTED READINESS' > scripts/check-ai-readiness.py
printf '%s\n' 'UNTRUSTED PRE-PUSH' > scripts/trusted-hooks/pre-push
printf '%s\n' 'UNTRUSTED CONFIG' > backends.json
git add .
git commit -qm 'fixture: divergent checkout'
checkout_sha="$(git rev-parse HEAD)"

if ! command -v codex >/dev/null 2>&1; then
  mkdir "$temporary/bin"
  printf '#!/bin/sh\nexit 0\n' > "$temporary/bin/codex"
  chmod 700 "$temporary/bin/codex"
  PATH="$temporary/bin:$PATH"
  export PATH
fi
git show refs/remotes/origin/main:scripts/install-git-hooks.sh | sh

bundle="$(git config --local --get core.hooksPath)"
common_dir="$(CDPATH= cd -- "$(git rev-parse --git-common-dir)" && pwd -P)"
if command -v cygpath >/dev/null 2>&1; then
  bundle="$(cygpath -u "$bundle")"
  common_dir="$(cygpath -u "$common_dir")"
fi
case "$bundle" in "$common_dir"/jdsnack-hooks-*) ;; *) echo 'hook path is not in git common dir' >&2; exit 1 ;; esac
test "$(cat "$bundle/trusted-source-ref")" = refs/remotes/origin/main
test "$(cat "$bundle/source-sha")" = "$main_sha"
test "$(cat "$bundle/trusted-source-sha")" = "$main_sha"
test "$(cat "$bundle/checkout-sha")" = "$checkout_sha"
test "$main_sha" != "$checkout_sha"
git show "refs/remotes/origin/main:scripts/trusted-hooks/pre-push" | cmp - "$bundle/pre-push"
git show "refs/remotes/origin/main:scripts/check-ai-readiness.py" | cmp - "$bundle/scripts/check-ai-readiness.py"
grep -Fq 'BUNDLE_ROOT=' "$bundle/scripts/pre-push-ai-review.sh"
grep -Fq 'ROOT_DIR="$(git rev-parse --show-toplevel)"' "$bundle/scripts/pre-push-ai-review.sh"
! grep -Fq 'UNTRUSTED' "$bundle/scripts/pre-push-ai-review.sh"
python_bin="$(git config --local --get jdsnack.python)"
"$python_bin" "$bundle/scripts/verify-hook-bundle.py" "$bundle"
cp "$bundle/pre-push" "$temporary/pre-push.trusted"
printf '%s\n' 'UNTRUSTED BUNDLE MUTATION' > "$bundle/pre-push"
if "$python_bin" "$bundle/scripts/verify-hook-bundle.py" "$bundle" >/dev/null 2>&1; then
  echo 'bundle digest verifier accepted a modified hook' >&2
  exit 1
fi
cp "$temporary/pre-push.trusted" "$bundle/pre-push"
echo 'Trusted hook bootstrap ignores divergent checkout sources and records both SHAs.'
