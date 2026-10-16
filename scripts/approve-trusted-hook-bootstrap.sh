#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: bash scripts/approve-trusted-hook-bootstrap.sh <staged-tree-sha>" >&2
  echo "       bash scripts/approve-trusted-hook-bootstrap.sh --revoke <staged-tree-sha>" >&2
  exit 2
}

if [ "$#" -eq 2 ] && [ "$1" = '--revoke' ]; then
  requested_tree="$2"
  [[ "$requested_tree" =~ ^[0-9a-f]{40,64}$ ]] || {
    echo 'ERROR: revocation requires the full lowercase Git tree SHA.' >&2
    exit 1
  }
  repo_root="$(git rev-parse --show-toplevel)"
  cd "$repo_root"
  approved_tree="$(git config --local --get jdsnack.trustedHookBootstrapTreeSha 2>/dev/null || true)"
  [ "$approved_tree" = "$requested_tree" ] || {
    echo 'ERROR: the requested bootstrap tree is not the locally approved tree.' >&2
    exit 1
  }
  git config --local --unset jdsnack.trustedHookBootstrapTreeSha
  git update-ref -d "refs/codex/trusted-hook-bootstrap/$requested_tree"
  echo "Revoked trusted-hook bootstrap tree $requested_tree."
  exit 0
fi

[ "$#" -eq 1 ] || usage
requested_tree="$1"
[[ "$requested_tree" =~ ^[0-9a-f]{40,64}$ ]] || {
  echo 'ERROR: bootstrap approval requires a full lowercase Git tree SHA.' >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
if ! git diff --quiet; then
  echo 'ERROR: stage or discard all unstaged tracked changes before approving the bootstrap tree.' >&2
  exit 1
fi
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo 'ERROR: add or remove all untracked files before approving the bootstrap tree.' >&2
  exit 1
fi

actual_tree="$(git write-tree)"
if [ "$actual_tree" != "$requested_tree" ]; then
  echo "ERROR: requested tree SHA does not match the staged checkout (expected $actual_tree)." >&2
  exit 1
fi

main_ref=refs/remotes/origin/main
main_sha="$(git rev-parse --verify "${main_ref}^{commit}" 2>/dev/null)" || {
  echo 'ERROR: fetch origin main before approving a bootstrap tree.' >&2
  exit 1
}
if ! git merge-base --is-ancestor "$main_sha" HEAD; then
  echo 'ERROR: current HEAD must include the fetched origin/main commit.' >&2
  exit 1
fi

approval_ref="refs/codex/trusted-hook-bootstrap/$requested_tree"
existing_approval="$(git config --local --get jdsnack.trustedHookBootstrapTreeSha 2>/dev/null || true)"
if [ -n "$existing_approval" ] && [ "$existing_approval" != "$requested_tree" ]; then
  echo 'ERROR: a different bootstrap tree is already approved; revoke that approval first.' >&2
  exit 1
fi
existing_ref_tree="$(git rev-parse --verify "${approval_ref}^{tree}" 2>/dev/null || true)"
if [ -n "$existing_ref_tree" ] && [ "$existing_ref_tree" != "$requested_tree" ]; then
  echo 'ERROR: the bootstrap approval ref already points to a different tree.' >&2
  exit 1
fi

if [ -z "$existing_ref_tree" ]; then
  git update-ref "$approval_ref" "$requested_tree"
fi
git config --local jdsnack.trustedHookBootstrapTreeSha "$requested_tree"
echo "Approved trusted-hook bootstrap tree $requested_tree. Review this exact tree before installing it."
