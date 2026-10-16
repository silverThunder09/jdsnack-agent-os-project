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
sources='scripts/trusted-hooks/pre-commit scripts/trusted-hooks/pre-push scripts/trusted-hooks/verify-hook-bundle.py scripts/trusted-hooks/render-reviewer.py scripts/trusted-hooks/verify-trusted-hook-bundle-acl.ps1 scripts/check-ai-readiness.py backends.json scripts/pre-push-ai-review.sh scripts/review-policy.json scripts/review-risk.ps1 scripts/secure-review-temp-acl.ps1 scripts/verify-codex-auth-permissions.ps1 scripts/codex-auth-permissions.ps1 scripts/review-path-safety.ps1 scripts/install-git-hooks.sh scripts/approve-trusted-hook-bootstrap.sh'
write_readiness_fixture() {
  local root="$1"
  mkdir -p "$root/.agent-os" "$root/docs" "$root/evals"
  printf '%s\n' 'threshold: 75' 'max_drift_days: 30' 'eval_pass_rate_threshold: 0.8' 'fail_on_broken_refs: true' 'modules: []' 'exclude: []' > "$root/.agent-os/ai-readiness.yml"
  printf '%s\n' 'Fixture checkout.' > "$root/README.md"
  printf '%s\n' '{"total":100,"meta":{"scored_at":"2026-10-16T00:00:00Z","git_branch":"fixture"}}' > "$root/docs/ai-readiness-score.json"
  printf '%s\n' '{"cases":[{"id":"fixture","prompt":"check","expected_paths":["README.md"],"required_checks":["readiness"],"constraints":["fixture"],"status":"active"}]}' > "$root/evals/context-tasks.json"
}
for source in $sources; do
  mkdir -p "$fixture/$(dirname "$source")"
  cp "$workspace/$source" "$fixture/$source"
done
write_readiness_fixture "$fixture"
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
test "$(cat "$bundle/trusted-source-kind")" = origin-main
test "$(cat "$bundle/source-sha")" = "$main_sha"
test "$(cat "$bundle/trusted-source-sha")" = "$main_sha"
test "$(cat "$bundle/checkout-sha")" = "$checkout_sha"
test "$main_sha" != "$checkout_sha"
git show "refs/remotes/origin/main:scripts/trusted-hooks/pre-push" | cmp - "$bundle/pre-push"
git show "refs/remotes/origin/main:scripts/check-ai-readiness.py" | cmp - "$bundle/scripts/check-ai-readiness.py"
grep -Fq 'BUNDLE_ROOT=' "$bundle/scripts/pre-push-ai-review.sh"
grep -Fq 'CHECKOUT_ROOT="$($git_bin rev-parse --show-toplevel 2>/dev/null)"' "$bundle/scripts/pre-push-ai-review.sh"
! grep -Fq 'UNTRUSTED' "$bundle/scripts/pre-push-ai-review.sh"
python_bin="$(git config --local --get jdsnack.python)"
"$python_bin" "$bundle/scripts/verify-hook-bundle.py" "$bundle"

active_root="$(git rev-parse --show-toplevel)"
if ! JDSNACK_AI_READINESS_ROOT="$active_root" "$python_bin" "$bundle/scripts/check-ai-readiness.py" > "$temporary/readiness-matching-root.log" 2>&1; then
  cat "$temporary/readiness-matching-root.log" >&2
  echo 'readiness checker rejected the active checkout root from the trusted bundle' >&2
  exit 1
fi
grep -Fq 'AI-readiness gate passed:' "$temporary/readiness-matching-root.log"

other_checkout="$temporary/other-repo"
mkdir -p "$other_checkout"
write_readiness_fixture "$other_checkout"
git -C "$other_checkout" init -q
git -C "$other_checkout" config user.name 'Other Readiness Fixture'
git -C "$other_checkout" config user.email 'other-readiness@example.invalid'
git -C "$other_checkout" add .
git -C "$other_checkout" commit -qm 'fixture: other valid checkout'
other_root="$(git -C "$other_checkout" rev-parse --show-toplevel)"
if JDSNACK_AI_READINESS_ROOT="$other_root" "$python_bin" "$bundle/scripts/check-ai-readiness.py" > "$temporary/readiness-mismatched-root.log" 2>&1; then
  echo 'readiness checker accepted a different valid Git checkout' >&2
  exit 1
fi
if ! grep -Fq 'JDSNACK_AI_READINESS_ROOT must match the active Git checkout root.' "$temporary/readiness-mismatched-root.log"; then
  cat "$temporary/readiness-mismatched-root.log" >&2
  echo 'readiness checker rejected a mismatched root for the wrong reason' >&2
  exit 1
fi

if ! JDSNACK_AI_READINESS_ROOT="$other_root" "$bundle/pre-commit" > "$temporary/trusted-pre-commit.log" 2>&1; then
  cat "$temporary/trusted-pre-commit.log" >&2
  echo 'trusted pre-commit did not override an inherited readiness root with the active checkout' >&2
  exit 1
fi
grep -Fq 'AI-readiness gate passed:' "$temporary/trusted-pre-commit.log"

cp "$bundle/pre-push" "$temporary/pre-push.trusted"
printf '%s\n' 'UNTRUSTED BUNDLE MUTATION' > "$bundle/pre-push"
if "$python_bin" "$bundle/scripts/verify-hook-bundle.py" "$bundle" >/dev/null 2>&1; then
  echo 'bundle digest verifier accepted a modified hook' >&2
  exit 1
fi
cp "$temporary/pre-push.trusted" "$bundle/pre-push"

# A branch-local bootstrap is accepted only after an exact staged-tree approval.
for source_file in scripts/install-git-hooks.sh scripts/approve-trusted-hook-bootstrap.sh \
  scripts/trusted-hooks/pre-push scripts/pre-push-ai-review.sh \
  scripts/check-ai-readiness.py backends.json; do
  mkdir -p "$(dirname "$source_file")"
  git show "refs/remotes/origin/main:$source_file" > "$source_file"
  git add "$source_file"
done
printf '%s\n' '# explicit approved bootstrap fixture' >> scripts/check-ai-readiness.py
git add scripts/check-ai-readiness.py
approved_tree="$(git write-tree)"
if sh scripts/install-git-hooks.sh --approved-bootstrap "$approved_tree" > "$temporary/unapproved-bootstrap.log" 2>&1; then
  echo 'installer accepted a bootstrap tree before explicit local approval' >&2
  exit 1
fi
if ! grep -Fq 'this bootstrap tree has not been explicitly approved' "$temporary/unapproved-bootstrap.log"; then
  cat "$temporary/unapproved-bootstrap.log" >&2
  echo 'unapproved bootstrap was rejected for an unexpected reason' >&2
  exit 1
fi
if bash scripts/approve-trusted-hook-bootstrap.sh 0000000000000000000000000000000000000000 > "$temporary/wrong-tree-approval.log" 2>&1; then
  echo 'bootstrap approval accepted a SHA that does not match the staged tree' >&2
  exit 1
fi
if ! grep -Fq 'requested tree SHA does not match the staged checkout' "$temporary/wrong-tree-approval.log"; then
  cat "$temporary/wrong-tree-approval.log" >&2
  echo 'wrong bootstrap SHA was rejected for an unexpected reason' >&2
  exit 1
fi
bash scripts/approve-trusted-hook-bootstrap.sh "$approved_tree"
approval_ref="refs/codex/trusted-hook-bootstrap/$approved_tree"
test "$(git config --local --get jdsnack.trustedHookBootstrapTreeSha)" = "$approved_tree"
test "$(git rev-parse --verify "${approval_ref}^{tree}")" = "$approved_tree"
if JDSNACK_HOOK_SOURCE_REF="$approval_ref" sh scripts/install-git-hooks.sh --approved-bootstrap "$approved_tree" > "$temporary/arbitrary-source-override.log" 2>&1; then
  echo 'installer accepted the arbitrary source-ref environment override' >&2
  exit 1
fi
grep -Fq 'arbitrary trusted hook source overrides are disabled' "$temporary/arbitrary-source-override.log"
sh scripts/install-git-hooks.sh --approved-bootstrap "$approved_tree"

bootstrap_bundle="$(git config --local --get core.hooksPath)"
if command -v cygpath >/dev/null 2>&1; then bootstrap_bundle="$(cygpath -u "$bootstrap_bundle")"; fi
test "$(cat "$bootstrap_bundle/trusted-source-kind")" = approved-bootstrap
test "$(cat "$bootstrap_bundle/trusted-source-ref")" = "$approval_ref"
test "$(cat "$bootstrap_bundle/source-sha")" = "$approved_tree"
test "$(cat "$bootstrap_bundle/trusted-source-sha")" = "$approved_tree"
git show "$approval_ref:scripts/trusted-hooks/pre-push" | cmp - "$bootstrap_bundle/pre-push"
"$python_bin" "$bootstrap_bundle/scripts/verify-hook-bundle.py" "$bootstrap_bundle"

git config --local jdsnack.trustedHookBootstrapTreeSha "$main_sha"
if "$python_bin" "$bootstrap_bundle/scripts/verify-hook-bundle.py" "$bootstrap_bundle" > "$temporary/revoked-bootstrap.log" 2>&1; then
  echo 'bundle verifier accepted a local approval value that differs from its pinned tree' >&2
  exit 1
fi
grep -Fq 'bundle does not match the locally approved bootstrap tree' "$temporary/revoked-bootstrap.log"
git config --local jdsnack.trustedHookBootstrapTreeSha "$approved_tree"
bash scripts/approve-trusted-hook-bootstrap.sh --revoke "$approved_tree"
if git config --local --get jdsnack.trustedHookBootstrapTreeSha >/dev/null 2>&1 ||
  git show-ref --verify --quiet "$approval_ref"; then
  echo 'bootstrap revocation left a local approval value or pinned ref behind' >&2
  exit 1
fi
if "$python_bin" "$bootstrap_bundle/scripts/verify-hook-bundle.py" "$bootstrap_bundle" > "$temporary/fully-revoked-bootstrap.log" 2>&1; then
  echo 'bundle verifier accepted an explicitly revoked bootstrap tree' >&2
  exit 1
fi

echo 'Trusted hook bootstrap accepts origin/main or an exact, locally approved tree and records its source kind.'
