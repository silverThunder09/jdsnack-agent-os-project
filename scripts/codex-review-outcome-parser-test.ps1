[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$workflowPath = Join-Path $Workspace '.github/workflows/codex-branch-review.yml'
$workflow = Get-Content -LiteralPath $workflowPath -Raw

function Get-ReviewOutcomePattern {
    param([string]$Name)

    $expression = '\$' + [regex]::Escape($Name) +
        ' = \[regex\]::Match\(\$report, ''([^'']+)''\)'
    $match = [regex]::Match($workflow, $expression)
    if (-not $match.Success) {
        throw "워크플로에서 $Name 정규식을 찾지 못했습니다."
    }
    return $match.Groups[1].Value
}

$decisionPattern = Get-ReviewOutcomePattern -Name 'decisionMatch'
$scorePattern = Get-ReviewOutcomePattern -Name 'scoreMatch'
foreach ($newline in @("`n", "`r`n")) {
    $report = "# Review Result${newline}- decision: PASS${newline}- score: 4/5${newline}"
    $decision = [regex]::Match($report, $decisionPattern)
    $score = [regex]::Match($report, $scorePattern)
    if (-not $decision.Success -or $decision.Groups[1].Value -ne 'PASS' -or
        -not $score.Success -or $score.Groups[1].Value -ne '4') {
        throw "리뷰 결과의 LF/CRLF 형식을 파싱하지 못했습니다."
    }
}

Write-Output 'Codex review outcome LF/CRLF parser contract passed'
