#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

hooks_path=".githooks"
trusted_hooks_dir=""
for hook in pre-commit pre-push; do
  if [ ! -f "$repo_root/$hooks_path/$hook" ]; then
    echo "ERROR: required Git hook is missing: $hooks_path/$hook" >&2
    exit 1
  fi
done

for required_file in \
  "scripts/check-ai-readiness.py" \
  "scripts/pre-push-ai-review.sh" \
  "scripts/review-policy.json" \
  "scripts/review-risk.ps1" \
  "scripts/codex-auth-permissions.ps1" \
  "scripts/verify-codex-auth-permissions.ps1" \
  "scripts/review-path-safety.ps1" \
  "backends.json"; do
  if [ ! -f "$repo_root/$required_file" ]; then
    echo "ERROR: Git hook dependency is missing: $required_file" >&2
    exit 1
  fi
done

require_tool() {
  tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Git hooks require $tool before core.hooksPath can be enabled." >&2
    exit 1
  fi
}

for required_tool in dirname env git grep tail sed head awk cmp rm chmod mktemp stat id jq codex cat cp mkdir; do
  require_tool "$required_tool"
done

git_bash_path="$(command -v bash || true)"
if [ -z "$git_bash_path" ] || [ ! -x "$git_bash_path" ]; then
  echo "ERROR: Git hooks require an executable Git Bash on PATH before core.hooksPath can be enabled." >&2
  exit 1
fi
case "$git_bash_path" in
  /*) ;;
  *) git_bash_path="$(cd "$(dirname "$git_bash_path")" && pwd -P)/$(basename "$git_bash_path")" ;;
esac

python_tool=""
python_path=""
for candidate in python3 python; do
  candidate_path="$(command -v "$candidate" || true)"
  if [ -n "$candidate_path" ] && "$candidate_path" --version >/dev/null 2>&1; then
    python_tool="$candidate"
    python_path="$candidate_path"
    case "$python_path" in
      [A-Za-z]:[\\/]*)
        if command -v cygpath >/dev/null 2>&1; then
          python_path="$(cygpath -u "$python_path")"
        fi
        ;;
    esac
    if [ ! -x "$python_path" ] && [ -x "${python_path}.exe" ]; then
      python_path="${python_path}.exe"
    fi
    break
  fi
done
if [ -z "$python_tool" ]; then
  echo "ERROR: Git hooks require Python (python3 or python) for AI readiness before core.hooksPath can be enabled." >&2
  exit 1
fi

if command -v pwsh >/dev/null 2>&1; then
  powershell_tool="pwsh"
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell_tool="powershell.exe"
else
  echo "ERROR: Git hooks require PowerShell (pwsh or powershell.exe) before core.hooksPath can be enabled." >&2
  exit 1
fi

if ! codex exec \
  --ephemeral \
  --ignore-user-config \
  --strict-config \
  --sandbox read-only \
  --skip-git-repo-check \
  --help >/dev/null 2>&1; then
  echo "ERROR: installed Codex CLI does not support the exec options required by the pre-push reviewer." >&2
  exit 1
fi

git_common_dir="$(git rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*|[A-Za-z]:[\\/]*) ;;
  *) git_common_dir="$repo_root/$git_common_dir" ;;
esac
git_common_dir="$(CDPATH= cd -- "$git_common_dir" && pwd -P)" || {
  echo "ERROR: Git common dir를 trusted hook 경로로 정규화할 수 없습니다." >&2
  exit 1
}
trusted_hooks_dir="$git_common_dir/jdsnack-hooks"
trusted_source_ref='refs/remotes/origin/main'
trusted_source_sha="$(git rev-parse --verify "${trusted_source_ref}^{commit}" 2>/dev/null)" || {
  echo "ERROR: independently trusted hook source refs/remotes/origin/main을 확인할 수 없습니다. 먼저 origin/main을 fetch하십시오." >&2
  exit 1
}
mkdir -p "$trusted_hooks_dir/scripts"
chmod 700 "$trusted_hooks_dir" "$trusted_hooks_dir/scripts"

copy_trusted_source() {
  source_path="$1"
  destination_path="$2"
  if ! MSYS_NO_PATHCONV=1 git cat-file -e "$trusted_source_ref:$source_path" 2>/dev/null; then
    echo "ERROR: trusted hook source가 origin/main에 없습니다: $source_path" >&2
    exit 1
  fi
  if [ -L "$destination_path" ]; then
    echo "ERROR: trusted Git hook destination은 심볼릭 링크일 수 없습니다: $destination_path" >&2
    exit 1
  fi
  MSYS_NO_PATHCONV=1 git show "$trusted_source_ref:$source_path" > "$destination_path" || {
    echo "ERROR: origin/main trusted hook source를 bundle로 복사할 수 없습니다: $source_path" >&2
    exit 1
  }
}

write_manifest_entry() {
  destination_path="$1"
  source_path="$2"
  source_blob="$(MSYS_NO_PATHCONV=1 git rev-parse "$trusted_source_ref:$source_path")" || {
    echo "ERROR: trusted hook source digest를 계산할 수 없습니다: $source_path" >&2
    exit 1
  }
  printf '%s %s\n' "$destination_path" "$source_blob" >> "$bundle_manifest"
}

copy_trusted_source '.githooks/pre-commit' "$trusted_hooks_dir/pre-commit"
copy_trusted_source '.githooks/pre-push' "$trusted_hooks_dir/pre-push"
copy_trusted_source 'scripts/check-ai-readiness.py' "$trusted_hooks_dir/scripts/check-ai-readiness.py"
copy_trusted_source 'backends.json' "$trusted_hooks_dir/backends.json"
copy_trusted_source 'scripts/pre-push-ai-review.sh' "$trusted_hooks_dir/scripts/pre-push-ai-review.sh"
for script_name in \
  review-policy.json \
  review-risk.ps1 \
  secure-review-temp-acl.ps1 \
  verify-codex-auth-permissions.ps1 \
  codex-auth-permissions.ps1 \
  review-path-safety.ps1; do
  copy_trusted_source "scripts/$script_name" "$trusted_hooks_dir/scripts/$script_name"
done
bundle_manifest="$trusted_hooks_dir/bundle-manifest"
: > "$bundle_manifest"
write_manifest_entry 'pre-commit' '.githooks/pre-commit'
write_manifest_entry 'pre-push' '.githooks/pre-push'
write_manifest_entry 'scripts/check-ai-readiness.py' 'scripts/check-ai-readiness.py'
write_manifest_entry 'backends.json' 'backends.json'
write_manifest_entry 'scripts/pre-push-ai-review.sh' 'scripts/pre-push-ai-review.sh'
for script_name in \
  review-policy.json \
  review-risk.ps1 \
  secure-review-temp-acl.ps1 \
  verify-codex-auth-permissions.ps1 \
  codex-auth-permissions.ps1 \
  review-path-safety.ps1; do
  write_manifest_entry "scripts/$script_name" "scripts/$script_name"
done
source_sha="$(git rev-parse HEAD)" || {
  echo "ERROR: trusted Git hook bundle의 source SHA를 확인할 수 없습니다." >&2
  exit 1
}
printf '%s\n' "$source_sha" > "$trusted_hooks_dir/source-sha"
printf '%s\n' "$trusted_source_sha" > "$trusted_hooks_dir/trusted-source-sha"
chmod 600 "$trusted_hooks_dir/source-sha" "$trusted_hooks_dir/trusted-source-sha" "$bundle_manifest"
chmod 700 "$trusted_hooks_dir/pre-commit" "$trusted_hooks_dir/pre-push" "$trusted_hooks_dir/scripts/pre-push-ai-review.sh"

git config --local jdsnack.hookBash "$git_bash_path"
git config --local jdsnack.python "$python_path"
configured_bash_path="$(git config --local --get jdsnack.hookBash)"
configured_bash_comparison="$configured_bash_path"
if command -v cygpath >/dev/null 2>&1; then
  configured_bash_comparison="$(cygpath -u "$configured_bash_path")" || {
    echo "ERROR: persisted Git Bash path could not be normalized: $configured_bash_path" >&2
    exit 1
  }
fi
if [ "$configured_bash_comparison" != "$git_bash_path" ] || [ ! -x "$configured_bash_path" ]; then
  echo "ERROR: verified Git Bash path could not be persisted: $configured_bash_path" >&2
  exit 1
fi
configured_python_path="$(git config --local --get jdsnack.python)"
if [ "$configured_python_path" != "$python_path" ] || [ ! -x "$configured_python_path" ]; then
  echo "ERROR: verified Python path could not be persisted: $configured_python_path" >&2
  exit 1
fi

for hook in pre-commit pre-push; do
  if [ ! -x "$repo_root/$hooks_path/$hook" ]; then
    chmod +x "$repo_root/$hooks_path/$hook"
  fi
done

git config --local core.hooksPath "$trusted_hooks_dir"
configured_path="$(git config --local --get core.hooksPath)"
configured_path_comparison="$configured_path"
trusted_hooks_comparison="$trusted_hooks_dir"
if command -v cygpath >/dev/null 2>&1; then
  configured_path_comparison="$(cygpath -u "$configured_path")" || {
    echo "ERROR: configured trusted hook path could not be normalized: $configured_path" >&2
    exit 1
  }
  trusted_hooks_comparison="$(cygpath -u "$trusted_hooks_dir")" || {
    echo "ERROR: trusted hook path could not be normalized: $trusted_hooks_dir" >&2
    exit 1
  }
fi
if [ "$configured_path_comparison" != "$trusted_hooks_comparison" ]; then
  echo "ERROR: core.hooksPath installation could not be verified: $configured_path" >&2
  exit 1
fi

echo "Git hook prerequisites verified: $git_bash_path, $python_tool, jq, $powershell_tool, Codex CLI and required Git Bash tools"
echo "Git hooks enabled: $configured_path (trusted outside checkout; pre-commit, pre-push)"
