$ErrorActionPreference = 'Stop'

function Resolve-PowerShellExecutable {
    param(
        [scriptblock]$CommandLookup = {
            param([string]$Name)
            Get-Command -Name $Name -ErrorAction SilentlyContinue
        }
    )

    foreach ($candidateName in @('pwsh', 'powershell.exe')) {
        $resolvedCommand = & $CommandLookup $candidateName | Select-Object -First 1
        if ($null -eq $resolvedCommand) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$resolvedCommand.Source)) {
            return [string]$resolvedCommand.Source
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$resolvedCommand.Path)) {
            return [string]$resolvedCommand.Path
        }
    }
    throw 'Risk assessment tests require PowerShell (pwsh or powershell.exe).'
}

$powerShellOnlyPath = Resolve-PowerShellExecutable -CommandLookup {
    param([string]$Name)
    if ($Name -eq 'powershell.exe') {
        return [pscustomobject]@{ Source = 'fixture-powershell.exe' }
    }
    return $null
}
if ($powerShellOnlyPath -ne 'fixture-powershell.exe') {
    throw 'PowerShell-only fallback runtime was not selected when pwsh was unavailable.'
}

$scriptPath = Join-Path $PSScriptRoot 'review-risk.ps1'
$powerShellPath = Resolve-PowerShellExecutable
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("jdsnack-review-risk-test-" + [guid]::NewGuid().ToString('N'))

function Invoke-RiskAssessmentProcess {
    param(
        [string]$Workspace,
        [string]$BaseSha,
        [string]$HeadSha,
        [string]$PolicyPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $processOutput = & $powerShellPath -NoLogo -NoProfile -File $scriptPath `
            -Workspace $Workspace `
            -BaseSha $BaseSha `
            -HeadSha $HeadSha `
            -PolicyPath $PolicyPath 2>&1 | Out-String
        $processExitCode = [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return [pscustomobject]@{
        ExitCode = $processExitCode
        Output = $processOutput
    }
}

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

function New-SingleFileAssessment {
    param(
        [string]$Name,
        [string]$RelativePath,
        [string]$Content
    )

    $fixtureRoot = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    $invokeFixtureGit = {
        param([string[]]$Arguments)
        $output = & git -C $fixtureRoot @Arguments
        if ([int]$LASTEXITCODE -ne 0) {
            throw "git $($Arguments -join ' ') failed for $Name with exit $LASTEXITCODE"
        }
        return $output
    }
    & $invokeFixtureGit @('init', '--quiet') | Out-Null
    & $invokeFixtureGit @('config', 'user.name', 'JDSnack Risk Test') | Out-Null
    & $invokeFixtureGit @('config', 'user.email', 'risk-test@example.invalid') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'README.md') -Value 'base' -Encoding utf8
    & $invokeFixtureGit @('add', 'README.md') | Out-Null
    & $invokeFixtureGit @('commit', '--quiet', '-m', 'test: seed band fixture') | Out-Null
    $fixtureBaseSha = ([string](& $invokeFixtureGit @('rev-parse', 'HEAD'))).Trim()

    $normalizedPath = $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $targetPath = Join-Path $fixtureRoot $normalizedPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
    Set-Content -LiteralPath $targetPath -Value $Content -Encoding utf8
    & $invokeFixtureGit @('add', '.') | Out-Null
    & $invokeFixtureGit @('commit', '--quiet', '-m', 'test: exercise risk band') | Out-Null
    $fixtureHeadSha = ([string](& $invokeFixtureGit @('rev-parse', 'HEAD'))).Trim()

    $policyPath = Join-Path $PSScriptRoot 'review-policy.json'
    $json = & $scriptPath -Workspace $fixtureRoot -BaseSha $fixtureBaseSha -HeadSha $fixtureHeadSha -PolicyPath $policyPath | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        throw "review-risk.ps1 failed for ${Name}: $json"
    }
    return ConvertFrom-Json -InputObject $json
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
    Assert-Equal $assessment.minimumApprovals 0 'high-risk additional approval count'
    Assert-Equal $assessment.requiresOwnerSignoff $false 'high-risk owner signoff disabled'
    Assert-Equal ($assessment.reviewLabels -contains 'Security') $true 'Security routing label'
    Assert-Equal ($assessment.reviewLabels -contains 'Test Coverage') $true 'Test Coverage routing label'
    Assert-Equal ($assessment.reviewLabels -contains 'Architecture') $true 'Architecture routing label'
    Assert-Equal ($assessment.topLevelScopes -contains 'backend/src/main/controller') $true 'controller logical scope'
    Assert-Equal ($assessment.topLevelScopes -contains 'backend/src/main/resources') $true 'resources logical scope'
    Assert-Equal $assessment.primaryReviewer 'codex' 'configured primary reviewer'
    Assert-Equal $assessment.dryRun $false 'automatic merge policy'

    $invalidShaResult = Invoke-RiskAssessmentProcess -Workspace $tempRoot -BaseSha 'invalid-base-sha' -HeadSha $headSha -PolicyPath $policyPath
    if ($invalidShaResult.ExitCode -eq 0) {
        throw "review-risk.ps1 did not report an invalid SHA as a failing process: $($invalidShaResult.Output)"
    }

    $tamperedDryRunPath = Join-Path $tempRoot 'tampered-dry-run-policy.json'
    $tamperedDryRunPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
    $tamperedDryRunPolicy.dryRun = $true
    $tamperedDryRunPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tamperedDryRunPath -Encoding utf8
    $tamperedDryRunResult = Invoke-RiskAssessmentProcess -Workspace $tempRoot -BaseSha $baseSha -HeadSha $headSha -PolicyPath $tamperedDryRunPath
    if ($tamperedDryRunResult.ExitCode -eq 0) {
        throw "review-risk.ps1 accepted a policy with dryRun=true: $($tamperedDryRunResult.Output)"
    }

    $policyPath = Join-Path $PSScriptRoot 'review-policy.json'
    foreach ($patternGroup in @('security', 'apiDbEnvironment', 'migration')) {
        $tamperedPolicyPath = Join-Path $tempRoot "tampered-$patternGroup-policy.json"
        $tamperedPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
        $tamperedPolicy.riskScore.pathPatterns.$patternGroup = @('^tampered$')
        $tamperedPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tamperedPolicyPath -Encoding utf8
        $tamperedResult = Invoke-RiskAssessmentProcess -Workspace $tempRoot -BaseSha $baseSha -HeadSha $headSha -PolicyPath $tamperedPolicyPath
        if ($tamperedResult.ExitCode -eq 0 -or $tamperedResult.Output -notmatch 'path patterns are not fixed|trusted fixed policy digest') {
            throw "tampered $patternGroup scoring path pattern was accepted: $($tamperedResult.Output)"
        }
    }

    foreach ($routingLabel in @('Security', 'Performance', 'Test Coverage', 'Architecture')) {
        $tamperedRoutingPath = Join-Path $tempRoot ("tampered-routing-$($routingLabel -replace ' ', '-')-policy.json")
        $tamperedRoutingPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
        $tamperedRoutingPolicy.reviewRouting.$routingLabel = @('^tampered$')
        $tamperedRoutingPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tamperedRoutingPath -Encoding utf8
        $tamperedRoutingResult = Invoke-RiskAssessmentProcess -Workspace $tempRoot -BaseSha $baseSha -HeadSha $headSha -PolicyPath $tamperedRoutingPath
        if ($tamperedRoutingResult.ExitCode -eq 0 -or $tamperedRoutingResult.Output -notmatch 'routing rules are not fixed|trusted fixed policy digest') {
            throw "tampered $routingLabel review routing rule was accepted: $($tamperedRoutingResult.Output)"
        }
    }

    $lightAssessment = New-SingleFileAssessment -Name 'light' -RelativePath 'docs/note.md' -Content 'small change'
    Assert-Equal $lightAssessment.riskScore 0 'light fixture score'
    Assert-Equal $lightAssessment.riskBand 'Light' 'light fixture band'
    Assert-Equal $lightAssessment.minimumApprovals 0 'light additional approval count'
    Assert-Equal $lightAssessment.autoMergePolicy 'allowed-after-passing-review-and-required-checks' 'light merge policy'

    $standardAssessment = New-SingleFileAssessment -Name 'standard' -RelativePath 'backend/src/main/controller/FixtureController.java' -Content 'class FixtureController {}'
    Assert-Equal $standardAssessment.riskScore 35 'standard fixture score'
    Assert-Equal $standardAssessment.riskBand 'Standard' 'standard fixture band'
    Assert-Equal $standardAssessment.minimumApprovals 0 'standard additional approval count'
    Assert-Equal $standardAssessment.autoMergePolicy 'allowed-after-passing-review-and-required-checks' 'standard merge policy'

    $shellTestAssessment = New-SingleFileAssessment -Name 'shell-test-path' -RelativePath 'scripts/pre-push-ai-review-test.sh' -Content '# fixture test'
    Assert-Equal $shellTestAssessment.componentScores.testGap 0 'scripts/*-test.sh test evidence'
    $powerShellTestAssessment = New-SingleFileAssessment -Name 'powershell-test-path' -RelativePath 'scripts/review-risk-test.ps1' -Content '# fixture test'
    Assert-Equal $powerShellTestAssessment.componentScores.testGap 0 'scripts/*-test.ps1 test evidence'
    Write-Output 'Review risk scoring tests passed'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
