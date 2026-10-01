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

require_tool() {
  tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Git hooks require $tool before core.hooksPath can be enabled." >&2
    exit 1
  fi
}

require_tool jq
require_tool codex
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
  --config 'sandbox_workspace_write.network_access=false' \
  --sandbox read-only \
  --skip-git-repo-check \
  --help >/dev/null 2>&1; then
  echo "ERROR: installed Codex CLI does not support the exec options required by the pre-push reviewer." >&2
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

echo "Git hook prerequisites verified: jq, $powershell_tool, codex"
echo "Git hooks enabled: $configured_path (pre-commit, pre-push)"
