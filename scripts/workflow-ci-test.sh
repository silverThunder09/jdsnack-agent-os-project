#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
AUTONOMOUS_WORKFLOW="$ROOT_DIR/.github/workflows/autonomous-loop.yml"

grep -Fq -- '        shell: powershell' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must run the Windows runner step through PowerShell' >&2; exit 1; }
grep -Fq -- 'git -c core.autocrlf=false checkout-index --all --force' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must restore LF shell scripts on the Windows runner' >&2; exit 1; }
grep -Fq -- 'wsl.exe wslpath -a' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must convert Windows paths before invoking WSL' >&2; exit 1; }
grep -Fq -- "-replace '\\\\', '/'" "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must normalize Windows separators before wslpath' >&2; exit 1; }
grep -Fq -- 'Convert-ToWslPath' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must validate WSL path conversion results' >&2; exit 1; }
grep -Fq -- 'wsl.exe bash -lc' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must invoke Bash through WSL explicitly' >&2; exit 1; }
grep -Fq -- 'bash scripts/autonomous-spec-loop.sh' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must invoke the coordinator script' >&2; exit 1; }
if grep -Fq -- '        shell: bash' "$AUTONOMOUS_WORKFLOW"; then
  echo 'autonomous loop must not rely on the Windows runner bash shell alias' >&2
  exit 1
fi

command -v pwsh >/dev/null 2>&1 \
  || { echo 'pwsh is required to execute the WSL path failure contract' >&2; exit 1; }
POWERSHELL_FUNCTION="$(awk '
  /^          function Convert-ToWslPath/ { capture=1 }
  capture {
    line = $0
    sub(/^          /, "", line)
    print line
    if ($0 == "          }") exit
  }
' "$AUTONOMOUS_WORKFLOW")"
test -n "$POWERSHELL_FUNCTION" \
  || { echo 'failed to extract Convert-ToWslPath from autonomous workflow' >&2; exit 1; }
pwsh -NoLogo -NoProfile -NonInteractive -Command "$POWERSHELL_FUNCTION
function wsl.exe {
  \$global:WSL_STUB_LAST_ARGUMENT = \$args[-1]
  switch (\$env:WSL_STUB_MODE) {
    'empty' { \$global:LASTEXITCODE = 0; return }
    'failure' { Write-Error 'stub failure'; \$global:LASTEXITCODE = 17; return }
    default { Write-Error 'stub warning'; '/mnt/c/runner/workspace'; \$global:LASTEXITCODE = 0 }
  }
}
\$actual = Convert-ToWslPath 'C:\\runner\\workspace'
if (\$actual -ne '/mnt/c/runner/workspace' -or \$global:WSL_STUB_LAST_ARGUMENT -match '\\\\') {
  throw 'normal WSL path conversion contract failed'
}
\$env:WSL_STUB_MODE = 'empty'
try {
  Convert-ToWslPath 'C:\\runner\\workspace'
  throw 'expected empty-output conversion to fail'
} catch {
  if (\$_.Exception.Message -notmatch 'WSL path conversion failed') { throw }
}
\$env:WSL_STUB_MODE = 'failure'
try {
  Convert-ToWslPath 'C:\\runner\\workspace'
  throw 'expected non-zero conversion to fail'
} catch {
  if (\$_.Exception.Message -notmatch 'stub failure') { throw }
}
Write-Output 'PowerShell WSL path failure contract passed'"

ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].each { |file| YAML.load_file(file) }'
./scripts/pr-ci-router-test.sh
./scripts/pr-feedback-workflow-test.sh
./scripts/codex-branch-review-workflow-test.sh

echo "Workflow CI contract passed"
