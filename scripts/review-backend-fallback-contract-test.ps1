[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $Workspace 'scripts/review-backend-fallback.ps1'
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Fallback script not found: $sourcePath"
}

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $sourcePath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "Fallback script parse failed: $sourcePath"
}

$functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-StructuredReviewSummary'
    }, $true)
if ($null -eq $functionAst) {
    throw 'Test-StructuredReviewSummary function was not found.'
}
. ([scriptblock]::Create($functionAst.Extent.Text))
foreach ($functionName in @('Resolve-ToolPath', 'Invoke-Tool', 'Get-StructuredField', 'Get-ExactlyOneStructuredMatch', 'Test-StructuredFindings', 'Get-StructuredReviewResult', 'Get-ClaudeFallbackReason')) {
    $dependencyAst = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
        }, $true)
    if ($null -eq $dependencyAst) {
        throw "$functionName function was not found."
    }
    . ([scriptblock]::Create($dependencyAst.Extent.Text))
}

$validSummary = @(
    '- correctness: PASS — concrete correctness evidence is present.'
    '- contract: PASS — concrete contract evidence is present.'
    '- tests: PASS — concrete test evidence is present.'
    '- security: PASS — concrete security evidence is present.'
    '- maintainability: PASS — concrete maintainability evidence is present.'
    '- score rationale: 5/5 — all five rubric lines have concrete evidence.'
    '- conclusion: the structured review is complete and auditable.'
)
if (-not (Test-StructuredReviewSummary -Summary ($validSummary -join [Environment]::NewLine) -Score 5)) {
    throw 'A valid seven-line review summary was rejected.'
}

foreach ($severity in @('P2', 'P3')) {
    $finding = "- $severity — a non-blocking finding must be reflected in the review summary."
    if (Test-StructuredReviewSummary -Summary ($validSummary -join [Environment]::NewLine) -Score 5 -Findings $finding) {
        throw "A $severity finding was accepted without a matching summary reference."
    }

    $referencedSummary = @($validSummary)
    $referencedSummary[6] = "- conclusion: the $severity finding is retained and the review remains auditable."
    if (-not (Test-StructuredReviewSummary -Summary ($referencedSummary -join [Environment]::NewLine) -Score 5 -Findings $finding)) {
        throw "A $severity finding referenced in the conclusion was rejected."
    }
}

foreach ($nonPassStatus in @('OK', 'SATISFIED')) {
    $weakerRubricSummary = @($validSummary)
    $weakerRubricSummary[0] = $weakerRubricSummary[0].Replace(': PASS ', ": $nonPassStatus ")
    if (Test-StructuredReviewSummary -Summary ($weakerRubricSummary -join [Environment]::NewLine) -Score 5) {
        throw "A rubric line using $nonPassStatus instead of PASS was accepted."
    }
}

$duplicateRubric = @($validSummary[0..4] + $validSummary[0] + $validSummary[5..6])
if (Test-StructuredReviewSummary -Summary ($duplicateRubric -join [Environment]::NewLine) -Score 5) {
    throw 'A duplicate rubric line was accepted.'
}

$duplicateConclusion = @($validSummary[0..5] + $validSummary[6] + $validSummary[6])
if (Test-StructuredReviewSummary -Summary ($duplicateConclusion -join [Environment]::NewLine) -Score 5) {
    throw 'A duplicate conclusion line was accepted.'
}

$extraLine = @($validSummary + '- unrelated extra evidence must be rejected.')
if (Test-StructuredReviewSummary -Summary ($extraLine -join [Environment]::NewLine) -Score 5) {
    throw 'An extra summary line was accepted.'
}

$validReview = @(
    'decision: PASS'
    'score: 5/5'
    'risk: Light'
    'findings:'
    '- none'
    'review_summary:'
    $validSummary
) -join [Environment]::NewLine
$validResult = Get-StructuredReviewResult -Text $validReview -ReviewerBackend 'claude' -FallbackReason 'none'
if (-not $validResult.FindingsContractValid -or -not $validResult.ReviewSummaryContractValid) {
    throw "A valid structured review result did not preserve both contract-valid flags (decision=$($validResult.DecisionMatch.Success), score=$($validResult.ScoreMatch.Success), risk=$($validResult.RiskMatch.Success), findings=$($validResult.FindingsContractValid), summary=$($validResult.ReviewSummaryContractValid))."
}
$splitDecisionReview = $validReview.Replace('decision: PASS', "decision:`nPASS")
$splitDecisionResult = Get-StructuredReviewResult -Text $splitDecisionReview -ReviewerBackend 'claude' -FallbackReason 'none'
if ($splitDecisionResult.DecisionMatch.Success) {
    throw 'A decision value split onto another line was accepted as a valid scalar field.'
}
$conflictingDecisionReview = $validReview.Replace('decision: PASS', "decision: MAYBE`ndecision: PASS")
$conflictingDecisionResult = Get-StructuredReviewResult -Text $conflictingDecisionReview -ReviewerBackend 'claude' -FallbackReason 'none'
if ($conflictingDecisionResult.DecisionMatch.Success) {
    throw 'Conflicting decision headers were accepted as a valid structured result.'
}
$unreferencedFindingReview = $validReview.Replace('- none', '- P2 — the unresolved minor issue remains.')
$unreferencedFindingResult = Get-StructuredReviewResult -Text $unreferencedFindingReview -ReviewerBackend 'claude' -FallbackReason 'none'
if (-not $unreferencedFindingResult.FindingsContractValid -or $unreferencedFindingResult.ReviewSummaryContractValid) {
    throw 'A P2 finding without a summary reference was not isolated as a summary contract failure.'
}
$malformedFindingsReview = $validReview.Replace('- none', '- informational finding')
$malformedFindingsResult = Get-StructuredReviewResult -Text $malformedFindingsReview -ReviewerBackend 'claude' -FallbackReason 'none'
if ($malformedFindingsResult.FindingsContractValid) {
    throw 'Malformed findings were marked contract-valid.'
}
$malformedSummaryReview = $validReview.Replace('- conclusion: the structured review is complete and auditable.', '- conclusion: the structured review is complete and auditable.' + [Environment]::NewLine + '- conclusion: duplicate')
$malformedSummaryResult = Get-StructuredReviewResult -Text $malformedSummaryReview -ReviewerBackend 'claude' -FallbackReason 'none'
if ($malformedSummaryResult.ReviewSummaryContractValid) {
    throw 'Malformed review_summary was marked contract-valid.'
}

if ((Get-ClaudeFallbackReason -Output 'ERROR: Claude subscription access is disabled.') -ne 'claude-subscription') {
    throw 'A Claude subscription outage was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'ERROR: Authentication failed because the credential expired.') -ne 'claude-auth') {
    throw 'A Claude authentication outage was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'JDSNACK RUNNER: tool timed out after 120 seconds (claude).' -ExitCode 124) -ne 'claude-unavailable') {
    throw 'A Claude execution outage was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'JDSNACK RUNNER: tool unavailable on PATH (claude).' -ExitCode 127) -ne 'claude-unavailable') {
    throw 'An unavailable Claude executable was not classified for fallback.'
}
if ($null -ne (Get-ClaudeFallbackReason -Output 'review output mentions a timeout' -ExitCode 124)) {
    throw 'An unrelated process exit code 124 was incorrectly classified as a Claude timeout.'
}
if ($null -ne (Get-ClaudeFallbackReason -Output 'review output mentions an unavailable executable' -ExitCode 127)) {
    throw 'An unrelated process exit code 127 was incorrectly classified as an unavailable Claude executable.'
}
if ((Get-ClaudeFallbackReason -Output 'API ERROR: Claude rate limit exceeded.') -ne 'claude-quota') {
    throw 'An explicit Claude quota error was not classified for fallback.'
}
if ($null -ne (Get-ClaudeFallbackReason -Output 'Claude exited with an internal review error.')) {
    throw 'An unclassified Claude runner failure was incorrectly routed to Codex fallback.'
}
if ($null -ne (Get-ClaudeFallbackReason -Output 'decision: PASS')) {
    throw 'Malformed structured output without an availability signal was incorrectly routed to Codex fallback.'
}
$malformedReviewWithAvailabilityPhrase = "decision: NEEDS_HUMAN`nscore: 1/5`nrisk: Standard`nfindings:`n- P2 — the review timed out in a quoted example.`nreview_summary:`nnot a valid summary"
if ($null -ne (Get-ClaudeFallbackReason -Output $malformedReviewWithAvailabilityPhrase)) {
    throw 'Malformed review content mentioning a timeout was incorrectly classified as a Claude availability outage.'
}
$ioTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-tool-stream-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $ioTempRoot -Force | Out-Null
$ioFixturePath = Join-Path $ioTempRoot 'native-stream-fixture.ps1'
$ioOutputPath = Join-Path $ioTempRoot 'native-stream.stdout.log'
$ioErrorPath = Join-Path $ioTempRoot 'native-stream.stderr.log'
try {
@'
[System.Console]::Out.WriteLine('review text mentions a timeout, but is standard output')
[System.Console]::Error.WriteLine('ERROR: Claude subscription access is disabled.')
'@ | Set-Content -LiteralPath $ioFixturePath -Encoding utf8
$ioExitCode = Invoke-Tool -Name 'pwsh' -Arguments @('-NoProfile', '-File', $ioFixturePath) -OutputPath $ioOutputPath -TimeoutSeconds 30 -ErrorOutputPath $ioErrorPath
$ioStandardOutput = Get-Content -LiteralPath $ioOutputPath -Raw
$ioStandardError = Get-Content -LiteralPath $ioErrorPath -Raw
if ($ioExitCode -ne 0 -or
    $ioStandardOutput -notmatch 'standard output' -or
    $ioStandardError -notmatch 'ERROR: Claude subscription access is disabled' -or
    $ioStandardError -match 'standard output') {
    throw "Invoke-Tool did not preserve separate stdout/stderr for fallback classification (exit=$ioExitCode, stdout=$ioStandardOutput, stderr=$ioStandardError)."
}
} finally {
    Remove-Item -LiteralPath $ioTempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$passCommentFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-ExistingPassComment'
    }, $true)
if ($null -eq $passCommentFunctionAst) {
    throw 'Get-ExistingPassComment function was not found.'
}
. ([scriptblock]::Create($passCommentFunctionAst.Extent.Text))
$publishPassCommentFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Publish-PassComment'
    }, $true)
if ($null -eq $publishPassCommentFunctionAst) {
    throw 'Publish-PassComment function was not found.'
}
. ([scriptblock]::Create($publishPassCommentFunctionAst.Extent.Text))

$passCommentTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-pass-comment-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $passCommentTempRoot -Force | Out-Null
try {
    $script:fallbackRoot = $passCommentTempRoot
    $script:Repository = 'silverThunder09/jdsnack-agent-os-project'
    $script:PullRequestNumber = 220
    $script:passCommentFakeGhPath = Join-Path $passCommentTempRoot 'gh.ps1'
    $passCommentLog = Join-Path $passCommentTempRoot 'gh-commands.log'
    $passCommentFixture = Join-Path $passCommentTempRoot 'comments.json'
    @'
$arguments = @($args | ForEach-Object { [string]$_ })
Add-Content -LiteralPath $env:JDSNACK_PASS_GH_LOG -Value ($arguments -join '|')
if ($arguments.Count -ge 2 -and $arguments[0] -eq 'api' -and $arguments[1] -eq 'user') {
    Write-Output $env:JDSNACK_PASS_GH_LOGIN
    $global:LASTEXITCODE = 0
    return
}
if ($arguments.Count -gt 0 -and $arguments[-1] -match '^repos/.+/issues/\d+/comments$') {
    Get-Content -LiteralPath $env:JDSNACK_PASS_GH_COMMENTS -Raw
    $global:LASTEXITCODE = 0
    return
}
$global:LASTEXITCODE = 0
'@ | Set-Content -LiteralPath $script:passCommentFakeGhPath -Encoding utf8
    function Resolve-ToolPath {
        param([string]$Name)
        if ($Name -eq 'gh') {
            return $script:passCommentFakeGhPath
        }
        return $null
    }
    $env:JDSNACK_PASS_GH_LOG = $passCommentLog
    $env:JDSNACK_PASS_GH_LOGIN = 'silverThunder09'
    $env:JDSNACK_PASS_GH_COMMENTS = $passCommentFixture

    $headSha = 'abcdef0123456789'
    $riskAssessment = [pscustomobject]@{
        componentScores = [pscustomobject]@{ security = 10; performance = 10 }
        riskScore = 20
        riskBand = 'Light'
        reviewLabels = @('Security')
        autoMergePolicy = 'dry-run'
        dryRun = $true
    }
    $reviewInputs = [pscustomobject]@{ RiskAssessment = $riskAssessment }
    $reviewResult = [pscustomobject]@{
        ReviewerBackend = 'claude'
        FallbackReason = 'none'
        DecisionLabel = 'PASS'
        ScoreLabel = '5/5'
        ReviewSummary = 'All required review checks passed.'
        Findings = '- none'
    }

    $matchingMarker = "<!-- jdsnack-review-result head:$headSha -->`n## JDSnack 리뷰 PASS"
    @(
        [pscustomobject]@{ id = 120; user = [pscustomobject]@{ login = 'another-user' }; body = $matchingMarker },
        [pscustomobject]@{ id = 121; user = [pscustomobject]@{ login = 'silverThunder09' }; body = '<!-- jdsnack-review-result head:older-head -->' },
        [pscustomobject]@{ id = 130; user = [pscustomobject]@{ login = 'silverThunder09' }; body = $matchingMarker },
        [pscustomobject]@{ id = 131; user = [pscustomobject]@{ login = 'silverThunder09' }; body = $matchingMarker }
    ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $passCommentFixture -Encoding utf8
    Publish-PassComment -Result $reviewResult -ReviewInputs $reviewInputs -BaseSha 'base-sha' -HeadSha $headSha
    $updateCommands = @(Get-Content -LiteralPath $passCommentLog)
    if (-not ($updateCommands | Where-Object { $_ -match 'api\|-X\|PATCH\|repos/silverThunder09/jdsnack-agent-os-project/issues/comments/131\|-F\|body=@' })) {
        throw 'A same-author PASS comment for the current head was not updated in place.'
    }
    if ($updateCommands | Where-Object { $_ -match '^pr\|comment\|' }) {
        throw 'An existing PASS comment generated a duplicate comment instead of an update.'
    }

    Clear-Content -LiteralPath $passCommentLog
    @(
        [pscustomobject]@{ id = 140; user = [pscustomobject]@{ login = 'another-user' }; body = $matchingMarker },
        [pscustomobject]@{ id = 141; user = [pscustomobject]@{ login = 'silverThunder09' }; body = '<!-- jdsnack-review-result head:older-head -->' }
    ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $passCommentFixture -Encoding utf8
    Publish-PassComment -Result $reviewResult -ReviewInputs $reviewInputs -BaseSha 'base-sha' -HeadSha $headSha
    $createCommands = @(Get-Content -LiteralPath $passCommentLog)
    if (-not ($createCommands | Where-Object { $_ -match '^pr\|comment\|220\|' })) {
        throw 'A new head without an owned PASS comment did not create a comment.'
    }
    if ($createCommands | Where-Object { $_ -match '\|-X\|PATCH\|' }) {
        throw 'A comment from another author or an older head was overwritten.'
    }
} finally {
    Remove-Item -LiteralPath $passCommentTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_PASS_GH_LOG -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_PASS_GH_LOGIN -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_PASS_GH_COMMENTS -ErrorAction SilentlyContinue
}

Write-Output 'Review backend fallback contract tests passed'
