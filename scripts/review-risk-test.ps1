$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'review-risk.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("jdsnack-review-risk-test-" + [guid]::NewGuid().ToString('N'))

function Invoke-Git {
    param([string[]]$Arguments)

    $output = & git -C $tempRoot @Arguments
    if ([int]$LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit $LASTEXITCODE"
    }
    return $output
}

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message (expected=$Expected actual=$Actual)"
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Invoke-Git @('init', '--quiet') | Out-Null
    Invoke-Git @('config', 'user.name', 'JDSnack Risk Test') | Out-Null
    Invoke-Git @('config', 'user.email', 'risk-test@example.invalid') | Out-Null
    Set-Content -LiteralPath (Join-Path $tempRoot 'README.md') -Value 'base' -Encoding utf8
    Invoke-Git @('add', 'README.md') | Out-Null
    Invoke-Git @('commit', '--quiet', '-m', 'test: seed risk fixture') | Out-Null
    $baseSha = ([string](Invoke-Git @('rev-parse', 'HEAD'))).Trim()

    New-Item -ItemType Directory -Path (Join-Path $tempRoot '.github/workflows') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'backend/src/main/resources/db/migration') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'backend/src/main/controller') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tempRoot '.github/workflows/review.yml') -Value 'name: review' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $tempRoot 'backend/src/main/resources/db/migration/V1__seed.sql') -Value 'create table fixture;' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $tempRoot 'backend/src/main/controller/FixtureController.java') -Value ('class FixtureController {' + ("`n" * 120) + '}') -Encoding utf8
    Set-Content -LiteralPath (Join-Path $tempRoot 'review-notes.md') -Value 'risk fixture scope' -Encoding utf8
    Invoke-Git @('add', '.') | Out-Null
    Invoke-Git @('commit', '--quiet', '-m', 'test: exercise high risk scoring') | Out-Null
    $headSha = ([string](Invoke-Git @('rev-parse', 'HEAD'))).Trim()

    $policyPath = Join-Path $PSScriptRoot 'review-policy.json'
    $json = & $scriptPath -Workspace $tempRoot -BaseSha $baseSha -HeadSha $headSha -PolicyPath $policyPath | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        throw "review-risk.ps1 failed: $json"
    }
    $assessment = ConvertFrom-Json -InputObject $json
    Assert-Equal $assessment.riskScore 100 'high-risk fixture score'
    Assert-Equal $assessment.riskBand 'High-risk' 'high-risk fixture band'
    Assert-Equal $assessment.minimumApprovals 2 'high-risk approval count'
    Assert-Equal $assessment.requiresOwnerSignoff $true 'high-risk owner signoff'
    Assert-Equal ($assessment.reviewLabels -contains 'Security') $true 'Security routing label'
    Assert-Equal ($assessment.reviewLabels -contains 'Test Coverage') $true 'Test Coverage routing label'
    Assert-Equal ($assessment.reviewLabels -contains 'Architecture') $true 'Architecture routing label'
    Assert-Equal $assessment.dryRun $true 'default dry-run policy'
    Write-Output 'Review risk scoring tests passed'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
