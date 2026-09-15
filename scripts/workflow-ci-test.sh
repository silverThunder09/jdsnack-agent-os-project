#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
AUTONOMOUS_WORKFLOW="$ROOT_DIR/.github/workflows/autonomous-loop.yml"

grep -Fq -- '        shell: powershell' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must run the Windows runner step through PowerShell' >&2; exit 1; }
grep -Fq -- 'wsl.exe wslpath -a' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must convert Windows paths before invoking WSL' >&2; exit 1; }
grep -Fq -- 'wsl.exe bash -lc' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must invoke Bash through WSL explicitly' >&2; exit 1; }
grep -Fq -- 'bash scripts/autonomous-spec-loop.sh' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must invoke the coordinator script' >&2; exit 1; }
if grep -Fq -- '        shell: bash' "$AUTONOMOUS_WORKFLOW"; then
  echo 'autonomous loop must not rely on the Windows runner bash shell alias' >&2
  exit 1
fi

ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].each { |file| YAML.load_file(file) }'
./scripts/pr-ci-router-test.sh
./scripts/pr-feedback-workflow-test.sh
./scripts/codex-branch-review-workflow-test.sh

echo "Workflow CI contract passed"
