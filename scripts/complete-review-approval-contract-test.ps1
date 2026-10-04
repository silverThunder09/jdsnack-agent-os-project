[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$checkPolicyPath = Join-Path $Workspace 'scripts/pr-check-policy.ps1'
if (-not (Test-Path -LiteralPath $checkPolicyPath -PathType Leaf)) {
    throw "Conditional PR check policy not found: $checkPolicyPath"
}
. $checkPolicyPath
$sourcePath = Join-Path $Workspace 'scripts/complete-review-approval.ps1'
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Approval script not found: $sourcePath"
}

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $sourcePath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "Approval script parse failed: $sourcePath"
}

$approvalSource = Get-Content -LiteralPath $sourcePath -Raw
$humanApprovalOffset = $approvalSource.IndexOf('$approvalSummary = Get-HumanApprovalSummary')
$minimumApprovalOffset = $approvalSource.IndexOf('Assert-MinimumHumanApprovalCount `')
if ($humanApprovalOffset -lt 0 -or $minimumApprovalOffset -lt 0 -or
    $approvalSource.IndexOf('& $script:ghPath pr merge $PullRequestNumber --repo $Repository --squash --delete-branch --auto') -lt 0 -or
    -not $approvalSource.Contains('. $prCheckPolicyPath') -or
    -not $approvalSource.Contains('Test-SuccessfulConditionalPrCheckSkip') -or
    -not $approvalSource.Contains('Get-ReviewCheckRunsForHead -ExpectedHeadSha $HeadSha') -or
    $approvalSource.Contains('if ([bool]$riskAssessment.dryRun)') -or
    $approvalSource.Contains('Get-OwnerAutoMergeSignoff') -or
    $approvalSource.Contains('Implementation and reviewer backend are both Codex fallback')) {
    throw 'Approval must enforce actual branch protection and queue Squash auto-merge without custom dry-run, owner-signoff, or same-backend gates.'
}

$functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-CurrentHeadApprovers'
    }, $true)
if ($null -eq $functionAst) {
    throw 'Get-CurrentHeadApprovers function was not found.'
}
. ([scriptblock]::Create($functionAst.Extent.Text))

$headSha = ('a' * 40) -join ''
$staleSha = ('b' * 40) -join ''
$latestByLogin = @{
    staleReviewer = [pscustomobject]@{ State = 'APPROVED'; CommitOid = $staleSha }
    currentReviewer = [pscustomobject]@{ State = 'APPROVED'; CommitOid = $headSha }
    dismissedReviewer = [pscustomobject]@{ State = 'DISMISSED'; CommitOid = $headSha }
    commentedReviewer = [pscustomobject]@{ State = 'COMMENTED'; CommitOid = $headSha }
    pendingReviewer = [pscustomobject]@{ State = 'PENDING'; CommitOid = $headSha }
    currentRequester = [pscustomobject]@{ State = 'CHANGES_REQUESTED'; CommitOid = $headSha }
}
$approvers = @(Get-CurrentHeadApprovers -LatestByLogin $latestByLogin -ExpectedHeadSha $headSha)
if ($approvers.Count -ne 1 -or $approvers[0] -ne 'currentReviewer') {
    throw 'Stale approvals or non-approvals were counted for the current head.'
}

$minimumApprovalFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-MinimumHumanApprovalCount'
    }, $true)
if ($null -eq $minimumApprovalFunctionAst) {
    throw 'Assert-MinimumHumanApprovalCount function was not found.'
}

$policyFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-FixedApprovalPolicy'
    }, $true)
if ($null -eq $policyFunctionAst) {
    throw 'Assert-FixedApprovalPolicy function was not found.'
}

function Stop-NeedsHuman {
    param([string]$Reason)
    throw $Reason
}
. ([scriptblock]::Create($minimumApprovalFunctionAst.Extent.Text))
$threeApprovalMinimumRejected = $false
try {
    Assert-MinimumHumanApprovalCount -ActualApprovals 2 -RiskMinimumApprovals 2 -BranchProtectionMinimumApprovals 3 -RiskBand 'High-risk'
} catch {
    $threeApprovalMinimumRejected = $true
    if ($_.Exception.Message -notmatch 'at least 3 human approval\(s\); found 2') {
        throw
    }
}
if (-not $threeApprovalMinimumRejected) {
    throw 'Two current-head approvals were accepted when branch protection requires three.'
}
Assert-MinimumHumanApprovalCount -ActualApprovals 3 -RiskMinimumApprovals 2 -BranchProtectionMinimumApprovals 3 -RiskBand 'High-risk'
Assert-MinimumHumanApprovalCount -ActualApprovals 0 -RiskMinimumApprovals 0 -BranchProtectionMinimumApprovals 0 -RiskBand 'High-risk'
$riskMinimumRejected = $false
try {
    Assert-MinimumHumanApprovalCount -ActualApprovals 2 -RiskMinimumApprovals 3 -BranchProtectionMinimumApprovals 2 -RiskBand 'High-risk'
} catch {
    $riskMinimumRejected = $true
    if ($_.Exception.Message -notmatch 'at least 3 human approval\(s\); found 2') {
        throw
    }
}
if (-not $riskMinimumRejected) {
    throw 'Two current-head approvals were accepted when the risk policy requires three.'
}

$reportFieldsFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-UniqueReviewReportFields'
    }, $true)
if ($null -eq $reportFieldsFunctionAst) {
    throw 'Assert-UniqueReviewReportFields function was not found.'
}
. ([scriptblock]::Create($reportFieldsFunctionAst.Extent.Text))
$reviewLabelsFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-ReviewLabelsMatchAssessment'
    }, $true)
if ($null -eq $reviewLabelsFunctionAst) {
    throw 'Test-ReviewLabelsMatchAssessment function was not found.'
}
. ([scriptblock]::Create($reviewLabelsFunctionAst.Extent.Text))
$validReport = @"
- reviewer backend: claude
- decision: PASS
- score: 4/5
- risk: High-risk
- risk score: 65/100
- risk band: High-risk
- review labels: Security, Architecture
- reviewed base SHA: $headSha
- reviewed head SHA: $headSha
"@
Assert-UniqueReviewReportFields -Report $validReport
foreach ($duplicateField in @('risk', 'risk score', 'risk band', 'review labels')) {
    $duplicateReport = "$validReport`r`n- ${duplicateField}: conflicting value"
    $duplicateFieldRejected = $false
    try {
        Assert-UniqueReviewReportFields -Report $duplicateReport
    } catch {
        $duplicateFieldRejected = $true
        if ($_.Exception.Message -notmatch 'exactly one') {
            throw
        }
    }
    if (-not $duplicateFieldRejected) {
        throw "A duplicate '$duplicateField' report field was accepted."
    }
}
if (-not (Test-ReviewLabelsMatchAssessment -ReportedLabels @('Security', 'Architecture') -ExpectedLabels @('Architecture', 'Security'))) {
    throw 'A review label set matching deterministic assessment was rejected because of ordering.'
}
foreach ($invalidReviewLabels in @(
        ,@('Security'),
        ,@('Security', 'Performance'),
        ,@('Security', 'Security')
    )) {
    if (Test-ReviewLabelsMatchAssessment -ReportedLabels $invalidReviewLabels -ExpectedLabels @('Security', 'Architecture')) {
        throw 'A missing, extra, or duplicated review label was accepted against deterministic assessment.'
    }
}

. ([scriptblock]::Create($policyFunctionAst.Extent.Text))
$policyPath = Join-Path $Workspace 'scripts/review-policy.json'
$validPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
Assert-FixedApprovalPolicy -ReviewPolicy $validPolicy
foreach ($tamperScenario in @('scoring-pattern', 'review-routing', 'size-threshold')) {
    $tamperedPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
    switch ($tamperScenario) {
        'scoring-pattern' { $tamperedPolicy.riskScore.pathPatterns.security[0] = '.*' }
        'review-routing' { $tamperedPolicy.reviewRouting.Security[0] = '.*' }
        'size-threshold' { $tamperedPolicy.riskScore.size.small.maxChangedLines = 101 }
    }
    $tamperedPolicyRejected = $false
    try {
        Assert-FixedApprovalPolicy -ReviewPolicy $tamperedPolicy
    } catch {
        $tamperedPolicyRejected = $true
        if ($_.Exception.Message -notmatch 'fixed policy digest') {
            throw
        }
    }
    if (-not $tamperedPolicyRejected) {
        throw "Assert-FixedApprovalPolicy accepted a tampered $tamperScenario field."
    }
}
$invalidDryRunPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$invalidDryRunPolicy.dryRun = $true
$dryRunRejected = $false
try {
    Assert-FixedApprovalPolicy -ReviewPolicy $invalidDryRunPolicy
} catch {
    $dryRunRejected = $true
    if ($_.Exception.Message -notmatch 'dryRun must be false') {
        throw
    }
}
if (-not $dryRunRejected) {
    throw 'Assert-FixedApprovalPolicy accepted dryRun=true.'
}

$branchProtectionFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-BranchProtectionApprovalRequirement'
    }, $true)
if ($null -eq $branchProtectionFunctionAst) {
    throw 'Get-BranchProtectionApprovalRequirement function was not found.'
}
. ([scriptblock]::Create($branchProtectionFunctionAst.Extent.Text))
$reviewCheckRunsFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-ReviewCheckRunsForHead'
    }, $true)
if ($null -eq $reviewCheckRunsFunctionAst) {
    throw 'Get-ReviewCheckRunsForHead function was not found.'
}
. ([scriptblock]::Create($reviewCheckRunsFunctionAst.Extent.Text))
$requiredCheckMatchFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-RequiredChecksMatchBranchProtection'
    }, $true)
if ($null -eq $requiredCheckMatchFunctionAst) {
    throw 'Assert-RequiredChecksMatchBranchProtection function was not found.'
}
. ([scriptblock]::Create($requiredCheckMatchFunctionAst.Extent.Text))
$requiredPrGatesFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-RequiredPrGatesPassing'
    }, $true)
if ($null -eq $requiredPrGatesFunctionAst) {
    throw 'Assert-RequiredPrGatesPassing function was not found.'
}
. ([scriptblock]::Create($requiredPrGatesFunctionAst.Extent.Text))
$currentReviewCheckFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-CurrentRunReviewCheck'
    }, $true)
if ($null -eq $currentReviewCheckFunctionAst) {
    throw 'Test-CurrentRunReviewCheck function was not found.'
}
. ([scriptblock]::Create($currentReviewCheckFunctionAst.Extent.Text))
$canonicalReviewCheckFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-CanonicalReviewChecks'
    }, $true)
if ($null -eq $canonicalReviewCheckFunctionAst) {
    throw 'Get-CanonicalReviewChecks function was not found.'
}
. ([scriptblock]::Create($canonicalReviewCheckFunctionAst.Extent.Text))
$currentRunReviewGateFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-CurrentRunReviewGate'
    }, $true)
if ($null -eq $currentRunReviewGateFunctionAst) {
    throw 'Assert-CurrentRunReviewGate function was not found.'
}
. ([scriptblock]::Create($currentRunReviewGateFunctionAst.Extent.Text))
$selectedReviewChecks = @(Get-CanonicalReviewChecks -Checks @(
        [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'pass' }
        [pscustomobject]@{ name = 'Codex Branch Review / run_review'; state = 'SUCCESS'; bucket = 'pass' }
        [pscustomobject]@{ name = 'publish_review_check'; state = 'SUCCESS'; bucket = 'pass' }
    ))
if ($selectedReviewChecks.Count -ne 1 -or $selectedReviewChecks[0].name -cne 'review') {
    throw 'The canonical PR-head review check was not isolated from the reviewer job check.'
}
$duplicateReviewChecks = @(Get-CanonicalReviewChecks -Checks @(
        [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'pass' }
        [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'pass' }
    ))
if ($duplicateReviewChecks.Count -ne 2) {
    throw 'Duplicate canonical review checks were not preserved for ambiguity rejection.'
}
$eligibleHumanApproverFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-EligibleHumanApprover'
    }, $true)
if ($null -eq $eligibleHumanApproverFunctionAst) {
    throw 'Test-EligibleHumanApprover function was not found.'
}
. ([scriptblock]::Create($eligibleHumanApproverFunctionAst.Extent.Text))
$humanApprovalFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-HumanApprovalSummary'
    }, $true)
if ($null -eq $humanApprovalFunctionAst) {
    throw 'Get-HumanApprovalSummary function was not found.'
}
. ([scriptblock]::Create($humanApprovalFunctionAst.Extent.Text))
$unresolvedChangesFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-NoUnresolvedChangeRequests'
    }, $true)
if ($null -eq $unresolvedChangesFunctionAst) {
    throw 'Assert-NoUnresolvedChangeRequests function was not found.'
}
. ([scriptblock]::Create($unresolvedChangesFunctionAst.Extent.Text))
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-approval-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $fakeGhPath = Join-Path $tempRoot 'gh.ps1'
    @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)
$global:LASTEXITCODE = 0
if ($Arguments -contains 'graphql') {
    $cursorArgument = @($Arguments | Where-Object { [string]$_ -like 'cursor=*' } | Select-Object -Last 1)
    $hasNextPage = $false
    $endCursor = $null
    $reviewNodes = @([pscustomobject]@{
        author = [pscustomobject]@{ login = 'contributor' }
        authorAssociation = 'CONTRIBUTOR'
        commit = [pscustomobject]@{ oid = $env:JDSNACK_FAKE_HEAD_SHA }
        databaseId = 1
        id = 'R1'
        state = 'APPROVED'
        submittedAt = '2026-10-02T00:00:00Z'
        createdAt = '2026-10-02T00:00:00Z'
    })
    function New-SyntheticReview {
        param(
            [string]$Id,
            [string]$State,
            [string]$CommitOid,
            [string]$Timestamp
        )
        [pscustomobject]@{
            author = [pscustomobject]@{ login = 'contributor' }
            authorAssociation = 'CONTRIBUTOR'
            commit = [pscustomobject]@{ oid = $CommitOid }
            databaseId = [int]($Id -replace '\D', '')
            id = $Id
            state = $State
            submittedAt = if ($State -eq 'PENDING') { $null } else { $Timestamp }
            createdAt = $Timestamp
        }
    }
    switch ($env:JDSNACK_FAKE_REVIEW_SCENARIO) {
        'commented' {
            $reviewNodes += [pscustomobject]@{
                author = [pscustomobject]@{ login = 'contributor' }
                authorAssociation = 'CONTRIBUTOR'
                commit = [pscustomobject]@{ oid = $env:JDSNACK_FAKE_HEAD_SHA }
                databaseId = 2
                id = 'R2'
                state = 'COMMENTED'
                submittedAt = '2026-10-02T01:00:00Z'
                createdAt = '2026-10-02T01:00:00Z'
            }
        }
        'pending' {
            $reviewNodes += [pscustomobject]@{
                author = [pscustomobject]@{ login = 'contributor' }
                authorAssociation = 'CONTRIBUTOR'
                commit = [pscustomobject]@{ oid = $env:JDSNACK_FAKE_HEAD_SHA }
                databaseId = 2
                id = 'R2'
                state = 'PENDING'
                submittedAt = $null
                createdAt = '2026-10-02T01:00:00Z'
            }
        }
        'changes-requested' {
            $reviewNodes += [pscustomobject]@{
                author = [pscustomobject]@{ login = 'contributor' }
                authorAssociation = 'CONTRIBUTOR'
                commit = [pscustomobject]@{ oid = $env:JDSNACK_FAKE_HEAD_SHA }
                databaseId = 2
                id = 'R2'
                state = 'CHANGES_REQUESTED'
                submittedAt = '2026-10-02T01:00:00Z'
                createdAt = '2026-10-02T01:00:00Z'
            }
        }
        'paginated-changes-requested' {
            if ($cursorArgument.Count -gt 0 -and [string]$cursorArgument[0] -eq 'cursor=review-page-2') {
                $reviewNodes = @([pscustomobject]@{
                    author = [pscustomobject]@{ login = 'contributor' }
                    authorAssociation = 'CONTRIBUTOR'
                    commit = [pscustomobject]@{ oid = $env:JDSNACK_FAKE_HEAD_SHA }
                    databaseId = 2
                    id = 'R2'
                    state = 'CHANGES_REQUESTED'
                    submittedAt = '2026-10-02T01:00:00Z'
                    createdAt = '2026-10-02T01:00:00Z'
                })
            } else {
                $hasNextPage = $true
                $endCursor = 'review-page-2'
            }
        }
        'same-timestamp-conflict' {
            $reviewNodes += [pscustomobject]@{
                author = [pscustomobject]@{ login = 'contributor' }
                authorAssociation = 'CONTRIBUTOR'
                commit = [pscustomobject]@{ oid = $env:JDSNACK_FAKE_HEAD_SHA }
                databaseId = 2
                id = 'R2'
                state = 'COMMENTED'
                submittedAt = '2026-10-02T00:00:00Z'
                createdAt = '2026-10-02T00:00:00Z'
            }
        }
        'stale-current-head' {
            $reviewNodes += [pscustomobject]@{
                author = [pscustomobject]@{ login = 'contributor' }
                authorAssociation = 'CONTRIBUTOR'
                commit = [pscustomobject]@{ oid = $env:JDSNACK_FAKE_STALE_SHA }
                databaseId = 2
                id = 'R2'
                state = 'APPROVED'
                submittedAt = '2026-10-02T01:00:00Z'
                createdAt = '2026-10-02T01:00:00Z'
            }
        }
        'stale-changes-requested-commented' {
            $reviewNodes = @(
                (New-SyntheticReview -Id 'R1' -State 'CHANGES_REQUESTED' -CommitOid $env:JDSNACK_FAKE_STALE_SHA -Timestamp '2026-10-02T00:00:00Z'),
                (New-SyntheticReview -Id 'R2' -State 'COMMENTED' -CommitOid $env:JDSNACK_FAKE_HEAD_SHA -Timestamp '2026-10-02T01:00:00Z')
            )
        }
        'stale-changes-requested-pending' {
            $reviewNodes = @(
                (New-SyntheticReview -Id 'R1' -State 'CHANGES_REQUESTED' -CommitOid $env:JDSNACK_FAKE_STALE_SHA -Timestamp '2026-10-02T00:00:00Z'),
                (New-SyntheticReview -Id 'R2' -State 'PENDING' -CommitOid $env:JDSNACK_FAKE_HEAD_SHA -Timestamp '2026-10-02T01:00:00Z')
            )
        }
        'stale-changes-requested-stale-approved' {
            $reviewNodes = @(
                (New-SyntheticReview -Id 'R1' -State 'CHANGES_REQUESTED' -CommitOid $env:JDSNACK_FAKE_STALE_SHA -Timestamp '2026-10-02T00:00:00Z'),
                (New-SyntheticReview -Id 'R2' -State 'APPROVED' -CommitOid $env:JDSNACK_FAKE_STALE_SHA -Timestamp '2026-10-02T01:00:00Z')
            )
        }
        'stale-changes-requested-current-approved' {
            $reviewNodes = @(
                (New-SyntheticReview -Id 'R1' -State 'CHANGES_REQUESTED' -CommitOid $env:JDSNACK_FAKE_STALE_SHA -Timestamp '2026-10-02T00:00:00Z'),
                (New-SyntheticReview -Id 'R2' -State 'APPROVED' -CommitOid $env:JDSNACK_FAKE_HEAD_SHA -Timestamp '2026-10-02T01:00:00Z')
            )
        }
        'stale-changes-requested-dismissed' {
            $reviewNodes = @(
                (New-SyntheticReview -Id 'R1' -State 'DISMISSED' -CommitOid $env:JDSNACK_FAKE_STALE_SHA -Timestamp '2026-10-02T00:00:00Z')
            )
        }
        'case-variant-same-user' {
            $reviewNodes += [pscustomobject]@{
                author = [pscustomobject]@{ login = 'Contributor' }
                authorAssociation = 'CONTRIBUTOR'
                commit = [pscustomobject]@{ oid = $env:JDSNACK_FAKE_HEAD_SHA }
                databaseId = 2
                id = 'R2'
                state = 'COMMENTED'
                submittedAt = '2026-10-02T01:00:00Z'
                createdAt = '2026-10-02T01:00:00Z'
            }
        }
        'case-variant-change-request-approved' {
            $latestApproval = New-SyntheticReview -Id 'R2' -State 'APPROVED' -CommitOid $env:JDSNACK_FAKE_HEAD_SHA -Timestamp '2026-10-02T01:00:00Z'
            $latestApproval.author.login = 'Contributor'
            $reviewNodes = @(
                (New-SyntheticReview -Id 'R1' -State 'CHANGES_REQUESTED' -CommitOid $env:JDSNACK_FAKE_STALE_SHA -Timestamp '2026-10-02T00:00:00Z'),
                $latestApproval
            )
        }
    }
    $review = [pscustomobject]@{
        data = [pscustomobject]@{
            repository = [pscustomobject]@{
                pullRequest = [pscustomobject]@{
                    author = [pscustomobject]@{ login = 'author' }
                    reviews = [pscustomobject]@{
                        nodes = @($reviewNodes)
                        pageInfo = [pscustomobject]@{ hasNextPage = $hasNextPage; endCursor = $endCursor }
                    }
                }
            }
        }
    }
    $review | ConvertTo-Json -Depth 10 -Compress
    exit 0
}
if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'api' -and ([string]$Arguments[1]) -match '^repos/.+/collaborators/.+/permission$') {
    if ($env:JDSNACK_FAKE_REVIEWER_PERMISSION -eq 'not-found') {
        Write-Output 'gh: Not Found (HTTP 404)'
        exit 1
    }
    [pscustomobject]@{ permission = $env:JDSNACK_FAKE_REVIEWER_PERMISSION } | ConvertTo-Json -Compress
    exit 0
}
if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'api' -and ([string]$Arguments[1]) -match '^repos/.+/commits/([0-9a-fA-F]{40})/check-runs\?check_name=review&per_page=100$') {
    $requestedHeadSha = $Matches[1]
    if (-not [string]::IsNullOrWhiteSpace($env:JDSNACK_FAKE_REVIEW_CHECK_RUNS_CAPTURE)) {
        Set-Content -LiteralPath $env:JDSNACK_FAKE_REVIEW_CHECK_RUNS_CAPTURE -Value ([string]$Arguments[1]) -Encoding Ascii
    }
    $checkHeadSha = if ([string]::IsNullOrWhiteSpace($env:JDSNACK_FAKE_REVIEW_CHECK_HEAD_SHA)) { $requestedHeadSha } else { $env:JDSNACK_FAKE_REVIEW_CHECK_HEAD_SHA }
    $checkRunId = if ([string]::IsNullOrWhiteSpace($env:JDSNACK_FAKE_REVIEW_CHECK_RUN_ID)) { '111111111' } else { $env:JDSNACK_FAKE_REVIEW_CHECK_RUN_ID }
    $reviewCheckRun = [pscustomobject]@{
        id = [long]$checkRunId
        name = 'review'
        head_sha = $checkHeadSha
        external_id = "jdsnack-review:silverThunder09/jdsnack-agent-os-project:$checkHeadSha"
        status = 'completed'
        conclusion = 'success'
        details_url = 'https://github.com/silverThunder09/jdsnack-agent-os-project/actions/runs/123456789'
        html_url = "https://github.com/silverThunder09/jdsnack-agent-os-project/runs/$checkRunId"
    }
    [pscustomobject]@{ total_count = 1; check_runs = @($reviewCheckRun) } | ConvertTo-Json -Depth 5 -Compress
    exit 0
}
if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'api' -and ([string]$Arguments[1]) -match '^repos/.+/branches/.+/protection$' -and -not [string]::IsNullOrWhiteSpace($env:JDSNACK_FAKE_BRANCH_PROTECTION_CAPTURE)) {
    Set-Content -LiteralPath $env:JDSNACK_FAKE_BRANCH_PROTECTION_CAPTURE -Value ([string]$Arguments[1]) -Encoding Ascii
}
if ($env:JDSNACK_FAKE_ZERO_APPROVALS -eq 'true') {
    $requiredReviews = [pscustomobject]@{ required_approving_review_count = 0; dismiss_stale_reviews = $false }
} elseif ($env:JDSNACK_FAKE_DISMISS_STALE -eq 'true') {
    $requiredApprovalCount = 2
    if ($env:JDSNACK_FAKE_REQUIRED_APPROVAL_COUNT) {
        $requiredApprovalCount = [int]$env:JDSNACK_FAKE_REQUIRED_APPROVAL_COUNT
    }
    $requiredReviews = [pscustomobject]@{ required_approving_review_count = $requiredApprovalCount; dismiss_stale_reviews = $true }
} else {
    $requiredReviews = [pscustomobject]@{ required_approving_review_count = 2; dismiss_stale_reviews = $false }
}
$protection = [ordered]@{ required_pull_request_reviews = $requiredReviews }
if ($env:JDSNACK_FAKE_STATUS_CHECKS -ne 'missing') {
    $requiredContexts = @('Validate Agent OS docs', 'Test and build backend', 'Build backend container', 'Test and build frontend')
    if ($env:JDSNACK_FAKE_CASE_VARIANT_CONTEXTS -eq 'true') {
        $requiredContexts += 'validate Agent OS docs'
    }
    $protection['required_status_checks'] = [pscustomobject]@{
        contexts = $requiredContexts
        checks = @([pscustomobject]@{ context = 'review'; app_id = 1 })
    }
}
$protection | ConvertTo-Json -Depth 10 -Compress
'@ | Set-Content -LiteralPath $fakeGhPath -Encoding utf8
    $script:ghPath = $fakeGhPath
    $script:Repository = 'silverThunder09/jdsnack-agent-os-project'
    $script:PullRequestNumber = 220
    $env:JDSNACK_FAKE_DISMISS_STALE = 'true'
    $env:JDSNACK_FAKE_STATUS_CHECKS = 'present'
    $protection = Get-BranchProtectionApprovalRequirement -BaseBranch 'main'
    if ([int]$protection.RequiredApprovals -ne 2 -or $protection.DismissStaleReviews -ne $true) {
        throw 'Valid branch protection was not returned as an enforced approval requirement.'
    }
    $env:JDSNACK_FAKE_REQUIRED_APPROVAL_COUNT = '3'
    $threeApprovalProtection = Get-BranchProtectionApprovalRequirement -BaseBranch 'main'
    if ([int]$threeApprovalProtection.RequiredApprovals -ne 3) {
        throw 'A branch-protection requirement greater than two approvals was not preserved.'
    }
    Remove-Item Env:JDSNACK_FAKE_REQUIRED_APPROVAL_COUNT -ErrorAction SilentlyContinue
    $env:JDSNACK_FAKE_ZERO_APPROVALS = 'true'
    $zeroApprovalProtection = Get-BranchProtectionApprovalRequirement -BaseBranch 'main'
    if ([int]$zeroApprovalProtection.RequiredApprovals -ne 0 -or $zeroApprovalProtection.DismissStaleReviews -ne $false) {
        throw 'A zero-approval branch without stale-review dismissal was rejected.'
    }
    Remove-Item Env:JDSNACK_FAKE_ZERO_APPROVALS -ErrorAction SilentlyContinue
    $branchProtectionCapturePath = Join-Path $tempRoot 'branch-protection-api-path.txt'
    $env:JDSNACK_FAKE_BRANCH_PROTECTION_CAPTURE = $branchProtectionCapturePath
    [void](Get-BranchProtectionApprovalRequirement -BaseBranch 'release/2026')
    $branchProtectionApiPath = (Get-Content -LiteralPath $branchProtectionCapturePath -Raw).Trim()
    if ($branchProtectionApiPath -ne 'repos/silverThunder09/jdsnack-agent-os-project/branches/release%2F2026/protection') {
        throw "A slash-containing base branch was not encoded as one API path segment: $branchProtectionApiPath"
    }
    Remove-Item Env:JDSNACK_FAKE_BRANCH_PROTECTION_CAPTURE -ErrorAction SilentlyContinue
    $reviewCheckRunsCapturePath = Join-Path $tempRoot 'review-check-runs-api-path.txt'
    $env:JDSNACK_FAKE_REVIEW_CHECK_RUNS_CAPTURE = $reviewCheckRunsCapturePath
    $currentHeadReviewRuns = @(Get-ReviewCheckRunsForHead -ExpectedHeadSha $headSha)
    $reviewCheckRunsApiPath = (Get-Content -LiteralPath $reviewCheckRunsCapturePath -Raw).Trim()
    Remove-Item Env:JDSNACK_FAKE_REVIEW_CHECK_RUNS_CAPTURE -ErrorAction SilentlyContinue
    $expectedReviewCheckRunsApiPath = "repos/silverThunder09/jdsnack-agent-os-project/commits/$headSha/check-runs?check_name=review&per_page=100"
    if ($reviewCheckRunsApiPath -cne $expectedReviewCheckRunsApiPath -or $currentHeadReviewRuns.Count -ne 1 -or $currentHeadReviewRuns[0].head_sha -ine $headSha) {
        throw 'Review check runs were not queried for the exact expected PR head SHA.'
    }
    $env:JDSNACK_FAKE_REVIEW_CHECK_HEAD_SHA = $staleSha
    $staleHeadReviewRunsRejected = $false
    try {
        [void](Get-ReviewCheckRunsForHead -ExpectedHeadSha $headSha)
    } catch {
        $staleHeadReviewRunsRejected = $true
        if ($_.Exception.Message -notmatch 'different PR head SHA') {
            throw
        }
    }
    Remove-Item Env:JDSNACK_FAKE_REVIEW_CHECK_HEAD_SHA -ErrorAction SilentlyContinue
    if (-not $staleHeadReviewRunsRejected) {
        throw 'A review check run for a different PR head SHA was returned as current.'
    }
    $expectedRequiredCheckContexts = @(
        'Validate Agent OS docs'
        'Build backend container'
        'review'
        'Test and build backend'
        'Test and build frontend'
    )
    if ($protection.RequiredCheckContexts.Count -ne $expectedRequiredCheckContexts.Count -or @($expectedRequiredCheckContexts | Where-Object { $_ -notin $protection.RequiredCheckContexts }).Count -gt 0) {
        throw 'Branch protection required check contexts were not returned completely.'
    }
    $matchingRequiredChecks = @($expectedRequiredCheckContexts | ForEach-Object { [pscustomobject]@{ name = $_; bucket = 'pass' } })
    $env:JDSNACK_FAKE_CASE_VARIANT_CONTEXTS = 'true'
    $caseVariantProtection = Get-BranchProtectionApprovalRequirement -BaseBranch 'main'
    Remove-Item Env:JDSNACK_FAKE_CASE_VARIANT_CONTEXTS -ErrorAction SilentlyContinue
    if ($caseVariantProtection.RequiredCheckContexts.Count -ne ($expectedRequiredCheckContexts.Count + 1) -or
        @($caseVariantProtection.RequiredCheckContexts | Where-Object { $_ -ceq 'Validate Agent OS docs' }).Count -ne 1 -or
        @($caseVariantProtection.RequiredCheckContexts | Where-Object { $_ -ceq 'validate Agent OS docs' }).Count -ne 1) {
        throw 'Branch protection check contexts that differ only by case were collapsed.'
    }
    $caseVariantCompleteChecks = @($matchingRequiredChecks + [pscustomobject]@{ name = 'validate Agent OS docs'; bucket = 'pass' })
    Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $caseVariantProtection.RequiredCheckContexts -RequiredChecks $caseVariantCompleteChecks
    $missingCaseVariantRejected = $false
    try {
        Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $caseVariantProtection.RequiredCheckContexts -RequiredChecks $matchingRequiredChecks
    } catch {
        $missingCaseVariantRejected = $true
        if ($_.Exception.Message -notmatch 'does not match gh pr checks --required') {
            throw
        }
    }
    if (-not $missingCaseVariantRejected) {
        throw 'A required context that differs only by case and is absent from gh pr checks was accepted.'
    }
    Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $protection.RequiredCheckContexts -RequiredChecks $matchingRequiredChecks
    $missingRequiredCheckRejected = $false
    try {
        Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $protection.RequiredCheckContexts -RequiredChecks @($matchingRequiredChecks | Where-Object { $_.name -ne 'review' })
    } catch {
        $missingRequiredCheckRejected = $true
        if ($_.Exception.Message -notmatch 'does not match gh pr checks --required') {
            throw
        }
    }
    if (-not $missingRequiredCheckRejected) {
        throw 'A branch-protection required check missing from gh pr checks was accepted.'
    }
    $caseVariantRequiredChecks = @($matchingRequiredChecks | ForEach-Object {
            if ($_.name -ceq 'Validate Agent OS docs') {
                [pscustomobject]@{ name = 'validate Agent OS docs'; bucket = 'pass' }
            } else {
                $_
            }
        })
    $caseVariantRequiredCheckRejected = $false
    try {
        Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $protection.RequiredCheckContexts -RequiredChecks $caseVariantRequiredChecks
    } catch {
        $caseVariantRequiredCheckRejected = $true
        if ($_.Exception.Message -notmatch 'does not match gh pr checks --required') {
            throw
        }
    }
    if (-not $caseVariantRequiredCheckRejected) {
        throw 'A case-mismatched required check context was accepted as an exact match.'
    }
    $skippedOptionalRequiredChecks = @($matchingRequiredChecks | ForEach-Object {
            if ($_.name -in @('Validate Agent OS docs', 'Test and build backend', 'Test and build frontend', 'Build backend container')) {
                [pscustomobject]@{ name = $_.name; bucket = 'skipping' }
            } else {
                $_
            }
        })
    Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $protection.RequiredCheckContexts -RequiredChecks $skippedOptionalRequiredChecks
    $unknownRequiredContext = 'Unrecognized path-selected job'
    $unknownExpectedContexts = @($protection.RequiredCheckContexts + $unknownRequiredContext)
    $unknownSkippedRequiredChecks = @($matchingRequiredChecks + [pscustomobject]@{ name = $unknownRequiredContext; bucket = 'skipping' })
    $unknownSkipRejected = $false
    try {
        Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $unknownExpectedContexts -RequiredChecks $unknownSkippedRequiredChecks
    } catch {
        $unknownSkipRejected = $true
        if ($_.Exception.Message -notmatch 'not passing') {
            throw
        }
    }
    if (-not $unknownSkipRejected) {
        throw 'An unrecognized skipped required context was accepted.'
    }
    foreach ($nonPassingBucket in @('pending', 'fail', 'cancel', 'skipping')) {
        $nonPassingChecks = @($matchingRequiredChecks | ForEach-Object {
                if ($_.name -eq 'review') { [pscustomobject]@{ name = $_.name; bucket = $nonPassingBucket } }
                else { $_ }
            })
        $nonPassingCheckRejected = $false
        try {
            Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $protection.RequiredCheckContexts -RequiredChecks $nonPassingChecks
        } catch {
            $nonPassingCheckRejected = $true
            if ($_.Exception.Message -notmatch 'not passing') {
                throw
            }
        }
        if (-not $nonPassingCheckRejected) {
            throw "A required check with bucket '$nonPassingBucket' was accepted."
        }
    }
    $uppercasePassRequiredChecks = @($matchingRequiredChecks | ForEach-Object {
            if ($_.name -ceq 'Validate Agent OS docs') { [pscustomobject]@{ name = $_.name; bucket = 'PASS' } }
            else { $_ }
        })
    $uppercasePassRequiredCheckRejected = $false
    try {
        Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $protection.RequiredCheckContexts -RequiredChecks $uppercasePassRequiredChecks
    } catch {
        $uppercasePassRequiredCheckRejected = $true
        if ($_.Exception.Message -notmatch 'not passing') { throw }
    }
    if (-not $uppercasePassRequiredCheckRejected) {
        throw 'A required check with a non-canonical uppercase PASS bucket was accepted.'
    }
    $passingPrGates = @(
        [pscustomobject]@{ name = 'Validate PR contract'; bucket = 'pass' }
        [pscustomobject]@{ name = 'PR CI Gate'; bucket = 'pass' }
    )
    Assert-RequiredPrGatesPassing -Checks $passingPrGates
    $caseVariantPrGates = @(
        [pscustomobject]@{ name = 'validate PR contract'; bucket = 'pass' }
        [pscustomobject]@{ name = 'PR CI Gate'; bucket = 'pass' }
    )
    $caseVariantPrGateRejected = $false
    try {
        Assert-RequiredPrGatesPassing -Checks $caseVariantPrGates
    } catch {
        $caseVariantPrGateRejected = $true
    }
    if (-not $caseVariantPrGateRejected) {
        throw 'A case-mismatched PR gate name was accepted.'
    }
    $uppercasePassPrGates = @(
        [pscustomobject]@{ name = 'Validate PR contract'; bucket = 'PASS' }
        [pscustomobject]@{ name = 'PR CI Gate'; bucket = 'pass' }
    )
    $uppercasePassPrGateRejected = $false
    try {
        Assert-RequiredPrGatesPassing -Checks $uppercasePassPrGates
    } catch {
        $uppercasePassPrGateRejected = $true
    }
    if (-not $uppercasePassPrGateRejected) {
        throw 'A PR gate with a non-canonical uppercase PASS bucket was accepted.'
    }
    foreach ($coreGateName in @('Validate PR contract', 'PR CI Gate')) {
        $skippedCoreGate = @($passingPrGates | ForEach-Object {
                if ($_.name -eq $coreGateName) { [pscustomobject]@{ name = $_.name; bucket = 'skipping' } }
                else { $_ }
            })
        $skippedCoreGateRejected = $false
        try {
            Assert-RequiredPrGatesPassing -Checks $skippedCoreGate
        } catch {
            $skippedCoreGateRejected = $true
            if ($_.Exception.Message -notmatch 'not passing') {
                throw
            }
        }
        if (-not $skippedCoreGateRejected) {
            throw "A skipped core PR gate '$coreGateName' was accepted."
        }
    }
    $currentReviewCheck = [pscustomobject]@{
        name = 'review'
        state = 'SUCCESS'
        bucket = 'pass'
        link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/111111111'
    }
    $currentReviewCheckRun = $currentHeadReviewRuns[0]
    if (-not (Test-CurrentRunReviewCheck -Check $currentReviewCheck -ReviewCheckRun $currentReviewCheckRun -ReviewJobResult 'success' -Repository 'silverThunder09/jdsnack-agent-os-project' -ServerUrl 'https://github.com' -ExpectedHeadSha $headSha)) {
        throw 'A completed successful review check from this workflow run was not recognized.'
    }
    $detailsUrlReviewCheck = $currentReviewCheck | Select-Object *
    $detailsUrlReviewCheck.link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/actions/runs/123456789'
    if (-not (Test-CurrentRunReviewCheck -Check $detailsUrlReviewCheck -ReviewCheckRun $currentReviewCheckRun -ReviewJobResult 'success' -Repository 'silverThunder09/jdsnack-agent-os-project' -ServerUrl 'https://github.com' -ExpectedHeadSha $headSha)) {
        throw 'The current head review check details URL was not matched to its exact check-run metadata.'
    }
    Assert-CurrentRunReviewGate -Checks @($currentReviewCheck) -ReviewCheckRuns $currentHeadReviewRuns -ReviewJobResult 'success' -Repository 'silverThunder09/jdsnack-agent-os-project' -ServerUrl 'https://github.com' -ExpectedHeadSha $headSha
    $uppercaseConclusionReviewCheckRun = $currentReviewCheckRun | Select-Object *
    $uppercaseConclusionReviewCheckRun.conclusion = 'SUCCESS'
    if (Test-CurrentRunReviewCheck -Check $currentReviewCheck -ReviewCheckRun $uppercaseConclusionReviewCheckRun -ReviewJobResult 'success' -Repository 'silverThunder09/jdsnack-agent-os-project' -ServerUrl 'https://github.com' -ExpectedHeadSha $headSha) {
        throw 'A review check run with a non-canonical uppercase success conclusion was accepted.'
    }
    $previousHeadReviewCheckRun = [pscustomobject]@{
        name = 'review'
        head_sha = $staleSha
        external_id = "jdsnack-review:silverThunder09/jdsnack-agent-os-project:$staleSha"
        status = 'completed'
        conclusion = 'success'
    }
    $previousHeadReviewRejected = $false
    try {
        Assert-CurrentRunReviewGate -Checks @($currentReviewCheck) -ReviewCheckRuns @($previousHeadReviewCheckRun) -ReviewJobResult 'success' -Repository 'silverThunder09/jdsnack-agent-os-project' -ServerUrl 'https://github.com' -ExpectedHeadSha $headSha
    } catch {
        $previousHeadReviewRejected = $true
        if ($_.Exception.Message -notmatch 'different PR head') {
            throw
        }
    }
    if (-not $previousHeadReviewRejected) {
        throw 'A successful review check run for a previous PR head SHA was accepted.'
    }
    $stalePassedReviewCheck = [pscustomobject]@{
        name = 'review'
        state = 'SUCCESS'
        bucket = 'pass'
        link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/987654321'
    }
    $staleReviewRejected = $false
    try {
        Assert-CurrentRunReviewGate -Checks @($stalePassedReviewCheck) -ReviewCheckRuns $currentHeadReviewRuns -ReviewJobResult 'success' -Repository 'silverThunder09/jdsnack-agent-os-project' -ServerUrl 'https://github.com' -ExpectedHeadSha $headSha
    } catch {
        $staleReviewRejected = $true
        if ($_.Exception.Message -notmatch 'stale') {
            throw
        }
    }
    if (-not $staleReviewRejected) {
        throw 'A successful review check from a previous workflow run was accepted.'
    }
    foreach ($invalidCurrentReviewCheck in @(
            [pscustomobject]@{ name = 'review'; state = 'IN_PROGRESS'; bucket = 'pending'; link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/987654321' },
            [pscustomobject]@{ name = 'review'; state = 'IN_PROGRESS'; bucket = 'pending'; link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/111111111' },
            [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'skipping'; link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/111111111' },
            [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'PASS'; link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/111111111' },
            [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'fail'; link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/111111111' },
            [pscustomobject]@{ name = 'PR CI Gate'; state = 'IN_PROGRESS'; bucket = 'pending'; link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/111111111' },
            [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'pass'; link = "https://evil.example/silverThunder09/jdsnack-agent-os-project/runs/111111111" },
            [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'pass'; link = 'http://github.com/silverThunder09/jdsnack-agent-os-project/runs/111111111' },
            [pscustomobject]@{ name = 'review'; state = 'SUCCESS'; bucket = 'pass'; link = 'https://github.com/other/repository/runs/111111111' },
            [pscustomobject]@{ name = 'review'; state = 'FAILURE'; bucket = 'fail'; link = 'https://github.com/silverThunder09/jdsnack-agent-os-project/runs/111111111' }
        )) {
        if (Test-CurrentRunReviewCheck -Check $invalidCurrentReviewCheck -ReviewCheckRun $currentReviewCheckRun -ReviewJobResult 'success' -Repository 'silverThunder09/jdsnack-agent-os-project' -ServerUrl 'https://github.com' -ExpectedHeadSha $headSha) {
            throw 'A pending, failed, unrelated host, repository, or run review check was accepted as the current workflow review.'
        }
    }
    if (Test-CurrentRunReviewCheck -Check $currentReviewCheck -ReviewCheckRun $currentReviewCheckRun -ReviewJobResult 'failure' -Repository 'silverThunder09/jdsnack-agent-os-project' -ServerUrl 'https://github.com' -ExpectedHeadSha $headSha) {
        throw 'A completed review check was accepted without a successful upstream review job.'
    }
    foreach ($malformedRequiredCheck in @(
            [pscustomobject]@{ name = ''; bucket = 'pass' },
            [pscustomobject]@{ bucket = 'pass' }
        )) {
        $malformedRequiredCheckRejected = $false
        try {
            Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $protection.RequiredCheckContexts -RequiredChecks @($matchingRequiredChecks + $malformedRequiredCheck)
        } catch {
            $malformedRequiredCheckRejected = $true
            if ($_.Exception.Message -notmatch 'empty or malformed check name') {
                throw
            }
        }
        if (-not $malformedRequiredCheckRejected) {
            throw 'An empty or malformed gh pr checks --required name was accepted.'
        }
    }
    $env:JDSNACK_FAKE_HEAD_SHA = $headSha
    $env:JDSNACK_FAKE_STALE_SHA = $staleSha
    $env:JDSNACK_FAKE_REVIEWER_PERMISSION = 'read'
    $approvalSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($approvalSummary.Count -ne 0) {
        throw 'A read-only contributor review was counted as a protected-branch human approval.'
    }
    $env:JDSNACK_FAKE_REVIEWER_PERMISSION = 'not-found'
    $nonCollaboratorSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($nonCollaboratorSummary.Count -ne 0) {
        throw 'A non-collaborator review was counted as a protected-branch human approval.'
    }
    foreach ($eligiblePermission in @('admin', 'maintain', 'push', 'write')) {
        $env:JDSNACK_FAKE_REVIEWER_PERMISSION = $eligiblePermission
        $approvalSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
        if ($approvalSummary.Count -ne 1 -or $approvalSummary.Logins[0] -ne 'contributor') {
            throw "A '$eligiblePermission'-level collaborator review was not counted as a current-head human approval."
        }
    }
    $env:JDSNACK_FAKE_REVIEW_SCENARIO = 'commented'
    $commentedReviewSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($commentedReviewSummary.Count -ne 0 -or $commentedReviewSummary.ChangesRequested.Count -ne 0) {
        throw 'A later COMMENTED review did not supersede an earlier approval.'
    }
    $env:JDSNACK_FAKE_REVIEW_SCENARIO = 'pending'
    $pendingReviewSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($pendingReviewSummary.Count -ne 0 -or $pendingReviewSummary.ChangesRequested.Count -ne 0) {
        throw 'A later PENDING review without submittedAt did not supersede an earlier approval.'
    }
    $env:JDSNACK_FAKE_REVIEW_SCENARIO = 'changes-requested'
    $changesRequestedSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($changesRequestedSummary.Count -ne 0 -or $changesRequestedSummary.ChangesRequested.Count -ne 1 -or $changesRequestedSummary.ChangesRequested[0] -ne 'contributor') {
        throw 'A later CHANGES_REQUESTED review did not revoke approval and remain blocking.'
    }
    $env:JDSNACK_FAKE_REVIEW_SCENARIO = 'paginated-changes-requested'
    $paginatedSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($paginatedSummary.Count -ne 0 -or $paginatedSummary.ChangesRequested.Count -ne 1 -or $paginatedSummary.ChangesRequested[0] -ne 'contributor') {
        throw 'A later CHANGES_REQUESTED review on a subsequent page was not applied.'
    }
    foreach ($case in @(
            [pscustomobject]@{ Scenario = 'stale-changes-requested-commented'; ExpectedApprovals = 0; ShouldBlock = $true },
            [pscustomobject]@{ Scenario = 'stale-changes-requested-pending'; ExpectedApprovals = 0; ShouldBlock = $true },
            [pscustomobject]@{ Scenario = 'stale-changes-requested-stale-approved'; ExpectedApprovals = 0; ShouldBlock = $true },
            [pscustomobject]@{ Scenario = 'stale-changes-requested-current-approved'; ExpectedApprovals = 1; ShouldBlock = $false },
            [pscustomobject]@{ Scenario = 'stale-changes-requested-dismissed'; ExpectedApprovals = 0; ShouldBlock = $false }
        )) {
        $env:JDSNACK_FAKE_REVIEW_SCENARIO = $case.Scenario
        $summary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
        if ($summary.Count -ne $case.ExpectedApprovals) {
            throw "Unexpected approval count for change-request lifecycle '$($case.Scenario)'."
        }
        $isBlocked = $false
        try {
            Assert-NoUnresolvedChangeRequests -ApprovalSummary $summary
        } catch {
            $isBlocked = $_.Exception.Message -match 'Unresolved human change request'
            if (-not $isBlocked) {
                throw
            }
        }
        if ($isBlocked -ne $case.ShouldBlock) {
            throw "Unexpected unresolved change-request state for '$($case.Scenario)'."
        }
        if (($summary.ChangesRequested.Count -gt 0) -ne $case.ShouldBlock) {
            throw "Unexpected change-request summary for '$($case.Scenario)'."
        }
    }
    $env:JDSNACK_FAKE_REVIEW_SCENARIO = 'same-timestamp-conflict'
    $sameTimestampConflictRejected = $false
    try {
        [void](Get-HumanApprovalSummary -ExpectedHeadSha $headSha)
    } catch {
        $sameTimestampConflictRejected = $true
        if ($_.Exception.Message -notmatch 'conflicting states or commits at the same timestamp') {
            throw
        }
    }
    if (-not $sameTimestampConflictRejected) {
        throw 'Conflicting review states at the same timestamp were not rejected.'
    }
    $env:JDSNACK_FAKE_REVIEW_SCENARIO = 'stale-current-head'
    $staleCurrentHeadSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($staleCurrentHeadSummary.Count -ne 0) {
        throw 'A newer approval on a stale commit was counted for the current head.'
    }
    $env:JDSNACK_FAKE_REVIEW_SCENARIO = 'case-variant-same-user'
    $caseVariantSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($caseVariantSummary.Count -ne 0) {
        throw 'Case-variant GitHub logins were treated as separate reviewers.'
    }
    $env:JDSNACK_FAKE_REVIEW_SCENARIO = 'case-variant-change-request-approved'
    $caseVariantChangeRequestSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($caseVariantChangeRequestSummary.Count -ne 1 -or $caseVariantChangeRequestSummary.ChangesRequested.Count -ne 0) {
        throw 'A current-head approval with different login capitalization did not resolve the earlier change request from the same human reviewer.'
    }
    Remove-Item Env:JDSNACK_FAKE_REVIEW_SCENARIO -ErrorAction SilentlyContinue
    $env:JDSNACK_FAKE_STATUS_CHECKS = 'missing'
    $missingStatusChecksRejected = $false
    try {
        [void](Get-BranchProtectionApprovalRequirement -BaseBranch 'main')
    } catch {
        $missingStatusChecksRejected = $true
        if ($_.Exception.Message -notmatch 'has no required status check protection') {
            throw
        }
    }
    if (-not $missingStatusChecksRejected) {
        throw 'Branch protection without required status checks was accepted.'
    }
    $env:JDSNACK_FAKE_STATUS_CHECKS = 'present'
    $env:JDSNACK_FAKE_DISMISS_STALE = 'false'
    $staleProtectionRejected = $false
    try {
        [void](Get-BranchProtectionApprovalRequirement -BaseBranch 'main')
    } catch {
        $staleProtectionRejected = $true
        if ($_.Exception.Message -notmatch 'does not dismiss stale') {
            throw
        }
    }
    if (-not $staleProtectionRejected) {
        throw 'Branch protection without stale-review dismissal was accepted.'
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_FAKE_DISMISS_STALE -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_FAKE_HEAD_SHA -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_FAKE_STALE_SHA -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_FAKE_REVIEWER_PERMISSION -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_FAKE_REVIEW_SCENARIO -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_FAKE_STATUS_CHECKS -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_FAKE_BRANCH_PROTECTION_CAPTURE -ErrorAction SilentlyContinue
}


Write-Output 'Complete review approval contract tests passed'
