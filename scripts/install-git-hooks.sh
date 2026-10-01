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

echo "Git hooks enabled: $configured_path (pre-commit, pre-push)"
