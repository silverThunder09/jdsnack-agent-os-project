#!/bin/sh
set -eu

repo_root="$(CDPATH= cd -- "$(git rev-parse --show-toplevel)" && pwd -P)"
cd "$repo_root"
source_ref=refs/remotes/origin/main
if [ -n "${JDSNACK_HOOK_SOURCE_REF-}" ]; then
  echo 'ERROR: trusted hook source override is disabled; use refs/remotes/origin/main.' >&2
  exit 1
fi
source_sha="$(git rev-parse --verify "${source_ref}^{commit}" 2>/dev/null)" || {
  echo "ERROR: fetch origin main before installing trusted Git hooks (${source_ref} is missing)." >&2
  exit 1
}
checkout_sha="$(git rev-parse --verify 'HEAD^{commit}' 2>/dev/null)" || exit 1

source_files='scripts/trusted-hooks/pre-commit scripts/trusted-hooks/pre-push scripts/trusted-hooks/verify-hook-bundle.py scripts/trusted-hooks/render-reviewer.py scripts/trusted-hooks/verify-trusted-hook-bundle-acl.ps1 scripts/check-ai-readiness.py backends.json scripts/pre-push-ai-review.sh scripts/review-policy.json scripts/review-risk.ps1 scripts/secure-review-temp-acl.ps1 scripts/verify-codex-auth-permissions.ps1 scripts/codex-auth-permissions.ps1 scripts/review-path-safety.ps1'
for source_file in $source_files; do
  mode="$(git ls-tree "$source_ref" -- "$source_file" | awk 'NR == 1 {print $1}')"
  case "$mode" in
    100644|100755) ;;
    *) echo "ERROR: trusted source file is missing or is not a regular file: $source_file" >&2; exit 1 ;;
  esac
done

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Git hook installation requires $1." >&2
    exit 1
  }
}
for tool in dirname env git grep tail sed head awk cmp rm chmod mktemp stat id readlink jq base64 cat cp mkdir tr; do
  require_tool "$tool"
done

git_bash_path="$(command -v bash || true)"
[ -n "$git_bash_path" ] && [ -x "$git_bash_path" ] || { echo 'ERROR: executable Git Bash is required.' >&2; exit 1; }
python_tool=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" --version >/dev/null 2>&1; then python_tool="$candidate"; break; fi
done
[ -n "$python_tool" ] || { echo 'ERROR: Python is required for trusted hooks.' >&2; exit 1; }
python_path="$(command -v "$python_tool")"
codex_path="$(command -v codex || true)"
[ -n "$codex_path" ] || { echo 'ERROR: Codex CLI is required for the pre-push review.' >&2; exit 1; }
case "$codex_path" in /*|[A-Za-z]:[\\/]*) ;; *) echo "ERROR: Codex CLI path is not absolute: $codex_path" >&2; exit 1 ;; esac
if command -v cygpath >/dev/null 2>&1; then
  git_bash_path="$(cygpath -u "$git_bash_path")"
  python_path="$(cygpath -u "$python_path")"
  codex_path="$(cygpath -u "$codex_path")"
fi
git_bash_path="$(readlink -f -- "$git_bash_path")"
python_path="$(readlink -f -- "$python_path")"
codex_path="$(readlink -f -- "$codex_path")"
[ -x "$git_bash_path" ] && [ -x "$python_path" ] && [ -x "$codex_path" ] || {
  echo 'ERROR: Git Bash, Python, or Codex did not resolve to an executable file.' >&2
  exit 1
}
repo_canonical="$(pwd -P)"
codex_canonical="$codex_path"
if command -v cygpath >/dev/null 2>&1; then
  repo_canonical="$(cygpath -m "$repo_canonical" | tr '[:upper:]' '[:lower:]')"
  codex_canonical="$(cygpath -m "$codex_canonical" | tr '[:upper:]' '[:lower:]')"
fi
case "$codex_canonical" in "$repo_canonical"|"$repo_canonical"/*)
  echo 'ERROR: Codex CLI must be installed outside the checkout.' >&2; exit 1 ;;
esac

if command -v pwsh >/dev/null 2>&1; then powershell_tool="$(command -v pwsh)"
elif command -v powershell.exe >/dev/null 2>&1; then powershell_tool="$(command -v powershell.exe)"
else echo 'ERROR: PowerShell is required for trusted ACL validation.' >&2; exit 1
fi
if ! "$codex_path" exec --ephemeral --ignore-user-config --strict-config --sandbox read-only --skip-git-repo-check --help >/dev/null 2>&1; then
  echo 'ERROR: Codex CLI does not support the required read-only review options.' >&2
  exit 1
fi

git_common_dir="$(git rev-parse --git-common-dir)"
case "$git_common_dir" in /*|[A-Za-z]:[\\/]*) ;; *) git_common_dir="$repo_root/$git_common_dir" ;; esac
git_common_dir="$(CDPATH= cd -- "$git_common_dir" && pwd -P)"
umask 077
bundle="$(mktemp -d "$git_common_dir/jdsnack-hooks-${source_sha}.XXXXXX")"
mkdir "$bundle/scripts"
manifest="$bundle/bundle-manifest"
: > "$manifest"

copy_source() {
  source_file="$1" destination="$2"
  git show "$source_ref:$source_file" > "$bundle/$destination"
  source_blob="$(git rev-parse "$source_ref:$source_file")"
  printf '%s %s\n' "$destination" "$source_blob" >> "$manifest"
}
copy_source scripts/trusted-hooks/pre-commit pre-commit
copy_source scripts/trusted-hooks/pre-push pre-push
copy_source scripts/trusted-hooks/verify-hook-bundle.py scripts/verify-hook-bundle.py
copy_source scripts/trusted-hooks/verify-trusted-hook-bundle-acl.ps1 scripts/verify-trusted-hook-bundle-acl.ps1
for source_file in scripts/check-ai-readiness.py backends.json scripts/review-policy.json scripts/review-risk.ps1 scripts/secure-review-temp-acl.ps1 scripts/verify-codex-auth-permissions.ps1 scripts/codex-auth-permissions.ps1 scripts/review-path-safety.ps1; do
  copy_source "$source_file" "$source_file"
done
git show "$source_ref:scripts/pre-push-ai-review.sh" > "$bundle/scripts/pre-push-ai-review.source"
git show "$source_ref:scripts/trusted-hooks/render-reviewer.py" > "$bundle/render-reviewer.py"
"$python_path" "$bundle/render-reviewer.py" "$bundle/scripts/pre-push-ai-review.source" "$bundle/scripts/pre-push-ai-review.sh"
rm "$bundle/render-reviewer.py" "$bundle/scripts/pre-push-ai-review.source"
printf 'scripts/pre-push-ai-review.sh %s\n' "$(git hash-object "$bundle/scripts/pre-push-ai-review.sh")" >> "$manifest"

printf '%s\n' "$source_sha" > "$bundle/source-sha"
printf '%s\n' "$source_sha" > "$bundle/trusted-source-sha"
printf '%s\n' "$source_ref" > "$bundle/trusted-source-ref"
printf '%s\n' "$checkout_sha" > "$bundle/checkout-sha"
chmod 600 "$manifest" "$bundle/source-sha" "$bundle/trusted-source-sha" "$bundle/trusted-source-ref" "$bundle/checkout-sha"
chmod 700 "$bundle/pre-commit" "$bundle/pre-push" "$bundle/scripts/pre-push-ai-review.sh"

expected_paths='pre-commit|pre-push|bundle-manifest|source-sha|checkout-sha|trusted-source-sha|trusted-source-ref|scripts/verify-hook-bundle.py|scripts/verify-trusted-hook-bundle-acl.ps1|scripts/check-ai-readiness.py|backends.json|scripts/pre-push-ai-review.sh|scripts/review-policy.json|scripts/review-risk.ps1|scripts/secure-review-temp-acl.ps1|scripts/verify-codex-auth-permissions.ps1|scripts/codex-auth-permissions.ps1|scripts/review-path-safety.ps1'
acl_file="$bundle/scripts/verify-trusted-hook-bundle-acl.ps1"
acl_bundle="$bundle"
acl_codex="$codex_path"
acl_checkout="$repo_root"
if command -v cygpath >/dev/null 2>&1; then
  acl_file="$(cygpath -w "$acl_file")"
  acl_bundle="$(cygpath -w "$acl_bundle")"
  acl_codex="$(cygpath -w "$acl_codex")"
  acl_checkout="$(cygpath -w "$acl_checkout")"
  MSYS2_ARG_CONV_EXCL='*' "$powershell_tool" -NoProfile -NonInteractive -File "$acl_file" -Path "$acl_bundle" -ExpectedRelativePath "$expected_paths" -CodexPath "$acl_codex" -CheckoutPath "$acl_checkout"
else
  "$powershell_tool" -NoProfile -NonInteractive -File "$acl_file" -Path "$acl_bundle" -ExpectedRelativePath "$expected_paths" -CodexPath "$acl_codex" -CheckoutPath "$acl_checkout"
fi

git config --local jdsnack.hookBash "$git_bash_path"
git config --local jdsnack.python "$python_path"
git config --local jdsnack.codex "$codex_path"
git config --local core.hooksPath "$bundle"
configured_path="$(git config --local --get core.hooksPath)"
if command -v cygpath >/dev/null 2>&1; then configured_path="$(cygpath -u "$configured_path")"; bundle="$(cygpath -u "$bundle")"; fi
[ "$configured_path" = "$bundle" ] || { echo 'ERROR: core.hooksPath could not be verified.' >&2; exit 1; }
echo "Trusted Git hooks installed from ${source_ref} (${source_sha}); checkout ${checkout_sha}."
