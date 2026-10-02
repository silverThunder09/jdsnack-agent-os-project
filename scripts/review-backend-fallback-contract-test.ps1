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
foreach ($functionName in @('Get-StructuredField', 'Get-ExactlyOneStructuredMatch', 'Test-StructuredFindings', 'Get-StructuredReviewResult')) {
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

Write-Output 'Review backend fallback contract tests passed'
