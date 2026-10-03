param(
    [Parameter(Mandatory = $true)]
    [string]$Workspace,

    [Parameter(Mandatory = $true)]
    [string]$BaseSha,

    [Parameter(Mandatory = $true)]
    [string]$HeadSha,

    [string]$PolicyPath = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-ToolPath {
    param([string]$Name)

    try {
        $command = Get-Command $Name -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($command.Path)) {
            return $command.Path
        }
        return $command.Source
    } catch {
        return $null
    }
}

function Matches-AnyPattern {
    param(
        [string]$Value,
        [object[]]$Patterns
    )

    foreach ($pattern in @($Patterns)) {
        if ($Value -match [string]$pattern) {
            return $true
        }
    }
    return $false
}

function Assert-FixedReviewPolicy {
    param([pscustomobject]$ReviewPolicy)

    if ([string]$ReviewPolicy.primaryReviewer -notin @('claude', 'codex')) {
        throw 'The configured primary PR reviewer must be claude or codex.'
    }

    $expectedWeights = [ordered]@{
        security = 30
        apiDbEnvironment = 20
        sizeScope = 15
        testGap = 15
        migration = 20
    }
    foreach ($weightName in $expectedWeights.Keys) {
        if ($null -eq $ReviewPolicy.riskScore.weights.$weightName -or [int]$ReviewPolicy.riskScore.weights.$weightName -ne $expectedWeights[$weightName]) {
            throw "Review policy weight is not fixed for $weightName."
        }
    }
    if (
        [int]$ReviewPolicy.riskScore.size.small.maxChangedLines -ne 100 -or
        [int]$ReviewPolicy.riskScore.size.small.maxFiles -ne 5 -or
        [int]$ReviewPolicy.riskScore.size.small.maxScopes -ne 1 -or
        [int]$ReviewPolicy.riskScore.size.small.points -ne 0 -or
        [int]$ReviewPolicy.riskScore.size.medium.maxChangedLines -ne 300 -or
        [int]$ReviewPolicy.riskScore.size.medium.maxFiles -ne 10 -or
        [int]$ReviewPolicy.riskScore.size.medium.maxScopes -ne 2 -or
        [int]$ReviewPolicy.riskScore.size.medium.points -ne 8 -or
        [int]$ReviewPolicy.riskScore.size.largePoints -ne 15
    ) {
        throw 'Review policy size thresholds are not fixed.'
    }

    $expectedBands = @(
        [pscustomobject]@{ name = 'Light'; maxScore = 30; minimumApprovals = 0; autoMerge = 'allowed-after-passing-review-and-required-checks'; requiresOwnerSignoff = $false }
        [pscustomobject]@{ name = 'Standard'; maxScore = 60; minimumApprovals = 0; autoMerge = 'allowed-after-passing-review-and-required-checks'; requiresOwnerSignoff = $false }
        [pscustomobject]@{ name = 'High-risk'; maxScore = 100; minimumApprovals = 0; autoMerge = 'allowed-after-passing-review-and-required-checks'; requiresOwnerSignoff = $false }
    )
    $actualBands = @($ReviewPolicy.bands)
    if ($actualBands.Count -ne $expectedBands.Count) {
        throw 'Review policy must define exactly three fixed risk bands.'
    }
    for ($index = 0; $index -lt $expectedBands.Count; $index++) {
        $expected = $expectedBands[$index]
        $actual = $actualBands[$index]
        if (
            [string]$actual.name -ne $expected.name -or
            [int]$actual.maxScore -ne $expected.maxScore -or
            [int]$actual.minimumApprovals -ne $expected.minimumApprovals -or
            [string]$actual.autoMerge -ne $expected.autoMerge -or
            [bool]$actual.requiresOwnerSignoff -ne $expected.requiresOwnerSignoff
        ) {
            throw "Review policy risk band is not fixed: $($expected.name)."
        }
    }

    foreach ($label in @('Security', 'Performance', 'Test Coverage', 'Architecture')) {
        $property = $ReviewPolicy.reviewRouting.PSObject.Properties[$label]
        if ($null -eq $property -or @($property.Value).Count -eq 0) {
            throw "Review policy routing is missing a path rule for $label."
        }
    }
    $expectedScoringPathPatterns = [ordered]@{
        security = @(
            '^\.github/'
            '^\.githooks/'
            '(^|/)(scripts/review|\.agent-os/operations/review)'
            '(^|/)(AGENTS\.md|CLAUDE\.md|backends\.json)$'
            '(^|/)(auth|security|secret|credential|token|permission)([-_/.]|$)'
            '(^|/)\.env([^/]*)$'
        )
        apiDbEnvironment = @(
            '(^|/)(api|controller|repository|migration|migrations|schema)(/|\.|$)'
            '(^|/)(application[^/]*\.(yml|yaml|properties)|compose[^/]*\.ya?ml|Dockerfile[^/]*|backends\.json)$'
            '^frontend/src/services/'
        )
        migration = @(
            '(^|/)(db/migration|migrations)(/|$)'
            '\.sql$'
            '(^|/)(schema|flyway)(/|\.|$)'
        )
        source = @(
            '^(backend|frontend|scripts|\.github/workflows|\.githooks)/'
        )
        test = @(
            '(^|/)(test|tests)/'
            '(^|/).*([._-]test|[._-]spec)(\.[^/]*)?$'
            '^scripts/.*-test\.(sh|ps1)$'
        )
    }
    foreach ($scoringPatternGroup in $expectedScoringPathPatterns.GetEnumerator()) {
        $actualPatterns = @($ReviewPolicy.riskScore.pathPatterns.($scoringPatternGroup.Key))
        if ($actualPatterns.Count -ne @($scoringPatternGroup.Value).Count -or
            (($actualPatterns -join "`n") -ne (@($scoringPatternGroup.Value) -join "`n"))) {
            throw "Review policy scoring path patterns are not fixed: $($scoringPatternGroup.Key)."
        }
    }
    $expectedReviewRouting = [ordered]@{
        'Security' = @(
            '^\.github/'
            '^\.githooks/'
            '(^|/)(scripts/review|\.agent-os/operations/review)'
            '(^|/)(auth|security|secret|credential|token|permission|workflow)([-_/.]|$)'
            '(^|/)(AGENTS\.md|CLAUDE\.md|backends\.json)$'
        )
        'Performance' = @(
            '(^|/)(performance|benchmark|load|cache|async|worker|query|repository|sql)([-_/.]|$)'
            '^frontend/src/(components|hooks|pages|services)/'
        )
        'Test Coverage' = @(
            '^(backend|frontend|scripts|\.github/workflows|\.githooks)/'
            '(^|/)(test|tests)/'
        )
        'Architecture' = @(
            '^\.agent-os/'
            '^docs/architecture/'
            '^backend/'
            '^frontend/src/'
            '^\.github/'
            '^scripts/'
            '^\.githooks/'
            '(^|/)(AGENTS\.md|CLAUDE\.md|backends\.json)$'
        )
    }
    foreach ($routingRule in $expectedReviewRouting.GetEnumerator()) {
        $actualRules = @($ReviewPolicy.reviewRouting.($routingRule.Key))
        if ($actualRules.Count -ne @($routingRule.Value).Count -or
            (($actualRules -join "`n") -ne (@($routingRule.Value) -join "`n"))) {
            throw "Review policy routing rules are not fixed: $($routingRule.Key)."
        }
    }
    $routingPayload = [ordered]@{
        pathPatterns = $ReviewPolicy.riskScore.pathPatterns
        reviewRouting = $ReviewPolicy.reviewRouting
    }
    $canonicalRouting = $routingPayload | ConvertTo-Json -Depth 20 -Compress
    $routingBytes = [System.Text.Encoding]::UTF8.GetBytes($canonicalRouting)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $routingHash = (($sha256.ComputeHash($routingBytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $sha256.Dispose()
    }
    $expectedRoutingPolicyDigest = 'facb6cf57c1ffe7ba78c63e0f7538ce0423309ada0b49b5de947b108be7efc99'
    if ($routingHash -ne $expectedRoutingPolicyDigest) {
        throw 'Review policy path patterns and routing labels do not match the trusted fixed policy digest.'
    }
    if ($null -eq $ReviewPolicy.dryRun -or $ReviewPolicy.dryRun -isnot [bool]) {
        throw 'Review policy dryRun must be an explicit boolean.'
    }
    if ($ReviewPolicy.dryRun -ne $false) {
        throw 'Review policy dryRun must be false to enable score-based auto-merge.'
    }
}

function Get-LogicalReviewScope {
    param([string]$Path)

    $parts = @($Path -split '/')
    if ($parts.Count -le 1) {
        return '<root>'
    }
    switch ([string]$parts[0]) {
        '.agent-os' {
            return ".agent-os/$($parts[1])"
        }
        '.github' {
            return ".github/$($parts[1])"
        }
        'backend' {
            if ($parts.Count -ge 4) {
                return ($parts[0..3] -join '/')
            }
            return 'backend'
        }
        'frontend' {
            if ($parts.Count -ge 3) {
                return ($parts[0..2] -join '/')
            }
            return 'frontend'
        }
        'scripts' {
            return 'scripts'
        }
        default {
            return "$($parts[0])/$($parts[1])"
        }
    }
}

function Get-ReviewRiskAssessment {
    param(
        [string]$ReviewWorkspace,
        [string]$ReviewBaseSha,
        [string]$ReviewHeadSha,
        [string]$ReviewPolicyPath
    )

    if ($ReviewBaseSha -notmatch '^[0-9a-fA-F]{40}$' -or $ReviewHeadSha -notmatch '^[0-9a-fA-F]{40}$') {
        throw 'Risk assessment requires full 40-character base and head SHAs.'
    }
    if (-not (Test-Path -LiteralPath $ReviewWorkspace -PathType Container)) {
        throw "Risk assessment workspace does not exist: $ReviewWorkspace"
    }
    if ([string]::IsNullOrWhiteSpace($ReviewPolicyPath)) {
        $ReviewPolicyPath = Join-Path $ReviewWorkspace 'scripts/review-policy.json'
    }
    if (-not (Test-Path -LiteralPath $ReviewPolicyPath -PathType Leaf)) {
        throw "Review policy not found: $ReviewPolicyPath"
    }

    $policy = Get-Content -LiteralPath $ReviewPolicyPath -Raw | ConvertFrom-Json
    if ([int]$policy.version -ne 1) {
        throw "Unsupported review policy version: $($policy.version)"
    }
    Assert-FixedReviewPolicy -ReviewPolicy $policy

    $gitPath = Resolve-ToolPath 'git'
    if ([string]::IsNullOrWhiteSpace($gitPath)) {
        throw 'Git is unavailable for risk assessment.'
    }

    $range = "$ReviewBaseSha...$ReviewHeadSha"
    $changedPaths = @(& $gitPath -C $ReviewWorkspace diff --no-ext-diff --no-textconv --no-renames --name-only $range)
    $gitExitCode = [int]$LASTEXITCODE
    if ($gitExitCode -ne 0) {
        throw "Could not classify reviewed paths for $range (exit $gitExitCode)."
    }
    $changedPaths = @($changedPaths | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $numstat = @(& $gitPath -C $ReviewWorkspace diff --no-ext-diff --no-textconv --no-renames --numstat $range)
    $gitExitCode = [int]$LASTEXITCODE
    if ($gitExitCode -ne 0) {
        throw "Could not calculate changed lines for $range (exit $gitExitCode)."
    }
    $addedLines = 0
    $deletedLines = 0
    foreach ($line in $numstat) {
        $parts = ([string]$line) -split "`t"
        if ($parts.Count -lt 2) {
            continue
        }
        $added = 0
        $deleted = 0
        if ([int]::TryParse($parts[0], [ref]$added)) {
            $addedLines += $added
        }
        if ([int]::TryParse($parts[1], [ref]$deleted)) {
            $deletedLines += $deleted
        }
    }
    $changedLines = $addedLines + $deletedLines
    $topLevelScopes = @($changedPaths | ForEach-Object { Get-LogicalReviewScope -Path ([string]$_) } | Sort-Object -Unique)

    $patterns = $policy.riskScore.pathPatterns
    $securityPaths = @($changedPaths | Where-Object { Matches-AnyPattern $_ $patterns.security })
    $apiDbEnvironmentPaths = @($changedPaths | Where-Object { Matches-AnyPattern $_ $patterns.apiDbEnvironment })
    $migrationPaths = @($changedPaths | Where-Object { Matches-AnyPattern $_ $patterns.migration })
    $sourcePaths = @($changedPaths | Where-Object { Matches-AnyPattern $_ $patterns.source })
    $testPaths = @($changedPaths | Where-Object { Matches-AnyPattern $_ $patterns.test })

    $sizeRule = $policy.riskScore.size.small
    $sizePoints = [int]$sizeRule.points
    $sizeReason = 'small: changed lines <= 100, files <= 5, scopes <= 1'
    if (
        $changedLines -gt [int]$sizeRule.maxChangedLines -or
        $changedPaths.Count -gt [int]$sizeRule.maxFiles -or
        $topLevelScopes.Count -gt [int]$sizeRule.maxScopes
    ) {
        $mediumRule = $policy.riskScore.size.medium
        if (
            $changedLines -le [int]$mediumRule.maxChangedLines -and
            $changedPaths.Count -le [int]$mediumRule.maxFiles -and
            $topLevelScopes.Count -le [int]$mediumRule.maxScopes
        ) {
            $sizePoints = [int]$mediumRule.points
            $sizeReason = 'medium: changed lines <= 300, files <= 10, scopes <= 2'
        } else {
            $sizePoints = [int]$policy.riskScore.size.largePoints
            $sizeReason = 'large: changed lines > 300, files > 10, or scopes > 2'
        }
    }

    $testGapPoints = 0
    $testGapReason = 'test evidence present or no source paths changed'
    if ($sourcePaths.Count -gt 0 -and $testPaths.Count -eq 0) {
        $testGapPoints = [int]$policy.riskScore.weights.testGap
        $testGapReason = 'source paths changed without a matching test path'
    }

    $componentScores = [ordered]@{
        security = if ($securityPaths.Count -gt 0) { [int]$policy.riskScore.weights.security } else { 0 }
        apiDbEnvironment = if ($apiDbEnvironmentPaths.Count -gt 0) { [int]$policy.riskScore.weights.apiDbEnvironment } else { 0 }
        sizeScope = $sizePoints
        testGap = $testGapPoints
        migration = if ($migrationPaths.Count -gt 0) { [int]$policy.riskScore.weights.migration } else { 0 }
    }
    $total = ($componentScores.Values | Measure-Object -Sum).Sum

    $band = @($policy.bands | Where-Object { $total -le [int]$_.maxScore } | Select-Object -First 1)
    if ($band.Count -ne 1) {
        throw "No risk band covers score $total."
    }
    $band = $band[0]

    $routingLabels = @()
    $routingMatches = [ordered]@{}
    foreach ($property in $policy.reviewRouting.PSObject.Properties) {
        $label = [string]$property.Name
        $matched = @($changedPaths | Where-Object { Matches-AnyPattern $_ $property.Value })
        if ($matched.Count -gt 0) {
            $routingLabels += $label
            $routingMatches[$label] = $matched
        }
    }
    if ($routingLabels.Count -eq 0) {
        $routingLabels = @('Architecture')
        $routingMatches['Architecture'] = @('<no specialized path matched>')
    }

    [pscustomobject]@{
        policyVersion = [int]$policy.version
        primaryReviewer = [string]$policy.primaryReviewer
        dryRun = [bool]$policy.dryRun
        changedFiles = $changedPaths.Count
        changedLines = $changedLines
        addedLines = $addedLines
        deletedLines = $deletedLines
        topLevelScopes = $topLevelScopes
        changedPaths = $changedPaths
        componentScores = $componentScores
        componentReasons = [ordered]@{
            security = if ($securityPaths.Count -gt 0) { 'security path matched' } else { 'no security path matched' }
            apiDbEnvironment = if ($apiDbEnvironmentPaths.Count -gt 0) { 'API, DB, or environment path matched' } else { 'no API, DB, or environment path matched' }
            sizeScope = $sizeReason
            testGap = $testGapReason
            migration = if ($migrationPaths.Count -gt 0) { 'migration or SQL path matched' } else { 'no migration or SQL path matched' }
        }
        riskScore = [int]$total
        riskBand = [string]$band.name
        minimumApprovals = [int]$band.minimumApprovals
        autoMergePolicy = [string]$band.autoMerge
        requiresOwnerSignoff = [bool]$band.requiresOwnerSignoff
        reviewLabels = @($routingLabels)
        routingMatches = $routingMatches
        policy = $band
    }
}

try {
    $assessment = Get-ReviewRiskAssessment `
        -ReviewWorkspace $Workspace `
        -ReviewBaseSha $BaseSha `
        -ReviewHeadSha $HeadSha `
        -ReviewPolicyPath $PolicyPath
    $assessment | ConvertTo-Json -Depth 10 -Compress
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
