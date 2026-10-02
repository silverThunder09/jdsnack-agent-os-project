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
foreach ($functionName in @('Get-StructuredField', 'Get-ExactlyOneStructuredMatch', 'Test-StructuredFindings', 'Get-StructuredReviewResult', 'Get-ClaudeFallbackReason')) {
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
    throw 'A valid structured review result did not preserve both contract-valid flags.'
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

if ((Get-ClaudeFallbackReason -Output 'Claude subscription access is disabled.') -ne 'claude-subscription') {
    throw 'A Claude subscription outage was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'Authentication failed because the credential expired.') -ne 'claude-auth') {
    throw 'A Claude authentication outage was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'Claude review backend timed out after 120 seconds.') -ne 'claude-unavailable') {
    throw 'A Claude execution outage was not classified for fallback.'
}
if ($null -ne (Get-ClaudeFallbackReason -Output 'Claude exited with an internal review error.')) {
    throw 'An unclassified Claude runner failure was incorrectly routed to Codex fallback.'
}
if ($null -ne (Get-ClaudeFallbackReason -Output 'decision: PASS')) {
    throw 'Malformed structured output without an availability signal was incorrectly routed to Codex fallback.'
}

Write-Output 'Review backend fallback contract tests passed'
