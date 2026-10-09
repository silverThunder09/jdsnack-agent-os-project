#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

hooks_path=".githooks"
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

for required_tool in dirname env git grep tail sed head awk cmp rm chmod mktemp stat id jq codex cat; do
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
for candidate in python3 python; do
  candidate_path="$(command -v "$candidate" || true)"
  if [ -n "$candidate_path" ] && "$candidate_path" --version >/dev/null 2>&1; then
    python_tool="$candidate"
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

git config --local jdsnack.hookBash "$git_bash_path"
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

for hook in pre-commit pre-push; do
  if [ ! -x "$repo_root/$hooks_path/$hook" ]; then
    chmod +x "$repo_root/$hooks_path/$hook"
  fi
done

git config --local core.hooksPath "$hooks_path"
configured_path="$(git config --local --get core.hooksPath)"
if [ "$configured_path" != "$hooks_path" ]; then
  echo "ERROR: core.hooksPath installation could not be verified: $configured_path" >&2
  exit 1
fi

echo "Git hook prerequisites verified: $git_bash_path, $python_tool, jq, $powershell_tool, Codex CLI and required Git Bash tools"
echo "Git hooks enabled: $configured_path (pre-commit, pre-push)"
