#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
AUTONOMOUS_WORKFLOW="$ROOT_DIR/.github/workflows/autonomous-loop.yml"
PR_CI_ROUTER="$ROOT_DIR/.github/workflows/pr-ci-router.yml"

grep -Fxq -- '*.sh text eol=lf' "$ROOT_DIR/.gitattributes" \
  || { echo '.gitattributes must force tracked shell scripts to LF' >&2; exit 1; }

grep -Fq -- '        shell: powershell' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must run the Windows runner step through PowerShell' >&2; exit 1; }
grep -Fq -- '$trackedShellScriptOutput = git -c core.quotepath=false ls-files -z -- '\''*.sh'\''' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must enumerate shell scripts with NUL-safe Git paths' >&2; exit 1; }
grep -Fq -- ' -split [char]0 | Where-Object { $_ }' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must parse NUL-delimited Git paths' >&2; exit 1; }
grep -Fq -- '[System.IO.File]::WriteAllText' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must write normalized shell scripts on the Windows runner' >&2; exit 1; }
grep -Fq -- '-replace "`r`n", "`n" -replace "`r", "`n"' "$AUTONOMOUS_WORKFLOW" \
  || { echo 'autonomous loop must normalize CRLF and CR shell scripts on the Windows runner' >&2; exit 1; }
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

NORMALIZE_BLOCK="$(awk '
  /^          \$trackedShellScriptOutput =/ { capture=1 }
  capture {
    line = $0
    sub(/^          /, "", line)
    print line
  }
  capture && /^$/ { exit }
' "$AUTONOMOUS_WORKFLOW")"
test -n "$NORMALIZE_BLOCK" \
  || { echo 'failed to extract shell script normalization block from autonomous workflow' >&2; exit 1; }
NORMALIZE_BLOCK="$NORMALIZE_BLOCK" pwsh -NoLogo -NoProfile -NonInteractive -Command '
$workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("jdsnack-shell-normalize-" + [guid]::NewGuid().ToString())
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
New-Item -ItemType Directory -Path $workspace | Out-Null
try {
  [System.IO.File]::WriteAllText((Join-Path $workspace "crlf.sh"), "#!/usr/bin/env bash`r`nset -e`r`n", $utf8NoBom)
  [System.IO.File]::WriteAllText((Join-Path $workspace "cr.sh"), "line-one`rline-two`r", $utf8NoBom)
  $env:GITHUB_WORKSPACE = $workspace
  function git {
    $global:LASTEXITCODE = 0
    return ("crlf.sh" + [char]0 + "cr.sh" + [char]0)
  }
  Invoke-Expression $env:NORMALIZE_BLOCK
  foreach ($relativePath in @("crlf.sh", "cr.sh")) {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $workspace $relativePath))
    if ($bytes -contains [byte]13) { throw "carriage return remained in $relativePath" }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
      throw "UTF-8 BOM remained in $relativePath"
    }
  }
  Write-Output "PowerShell shell script LF normalization contract passed"
} finally {
  Remove-Item -LiteralPath $workspace -Recurse -Force
}'

ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].each { |file| YAML.load_file(file) }'
grep -Fq -- 'pull-requests: read' "$PR_CI_ROUTER" \
  || { echo 'PR CI Router must have pull-requests read permission for PR contract validation' >&2; exit 1; }
grep -Fq -- 'name: Validate PR contract' "$PR_CI_ROUTER" \
  || { echo 'PR CI Router must run the PR contract job' >&2; exit 1; }
grep -Fq -- 'bash scripts/pr-contract-test.sh' "$PR_CI_ROUTER" \
  || { echo 'PR CI Router must execute scripts/pr-contract-test.sh' >&2; exit 1; }
grep -Fq -- 'pr_contract' "$PR_CI_ROUTER" \
  || { echo 'PR CI Gate must include the PR contract result' >&2; exit 1; }
test -f "$ROOT_DIR/scripts/pr-contract-test.sh" \
  || { echo 'scripts/pr-contract-test.sh is missing' >&2; exit 1; }
bash -n "$ROOT_DIR/scripts/pr-contract-test.sh"
grep -Fq -- '^[[:space:]]*(TBD([[:space:][:punct:]]|$)|[-*][[:space:]]+TBD([[:space:][:punct:]]|$)|[-*][[:space:]]*[^:]+:[[:space:]]*TBD([[:space:][:punct:]]|$))' "$ROOT_DIR/scripts/pr-contract-test.sh" \
  || { echo 'PR contract must only reject standalone or field-value TBD placeholders' >&2; exit 1; }
if grep -Fq -- "'\bTBD\b'" "$ROOT_DIR/scripts/pr-contract-test.sh"; then
  echo 'PR contract must not reject prose mentions of TBD' >&2
  exit 1
fi
test -f "$ROOT_DIR/scripts/pr-contract-test-test.sh" \
  || { echo 'scripts/pr-contract-test-test.sh is missing' >&2; exit 1; }
bash -n "$ROOT_DIR/scripts/pr-contract-test-test.sh"
bash "$ROOT_DIR/scripts/pr-contract-test-test.sh"
./scripts/pr-ci-router-test.sh
./scripts/pr-feedback-workflow-test.sh
./scripts/codex-branch-review-workflow-test.sh

echo "Workflow CI contract passed"
