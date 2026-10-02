[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
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

. ([scriptblock]::Create($policyFunctionAst.Extent.Text))
$policyPath = Join-Path $Workspace 'scripts/review-policy.json'
$validPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
Assert-FixedApprovalPolicy -ReviewPolicy $validPolicy
$invalidDryRunPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$invalidDryRunPolicy.dryRun = $false
$dryRunRejected = $false
try {
    Assert-FixedApprovalPolicy -ReviewPolicy $invalidDryRunPolicy
} catch {
    $dryRunRejected = $true
    if ($_.Exception.Message -notmatch 'dryRun is fixed to true') {
        throw
    }
}
if (-not $dryRunRejected) {
    throw 'Assert-FixedApprovalPolicy accepted dryRun=false.'
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
$requiredCheckMatchFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-RequiredChecksMatchBranchProtection'
    }, $true)
if ($null -eq $requiredCheckMatchFunctionAst) {
    throw 'Assert-RequiredChecksMatchBranchProtection function was not found.'
}
. ([scriptblock]::Create($requiredCheckMatchFunctionAst.Extent.Text))
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
if ($env:JDSNACK_FAKE_DISMISS_STALE -eq 'true') {
    $requiredReviews = [pscustomobject]@{ required_approving_review_count = 2; dismiss_stale_reviews = $true }
} else {
    $requiredReviews = [pscustomobject]@{ required_approving_review_count = 2; dismiss_stale_reviews = $false }
}
$protection = [ordered]@{ required_pull_request_reviews = $requiredReviews }
if ($env:JDSNACK_FAKE_STATUS_CHECKS -ne 'missing') {
    $protection['required_status_checks'] = [pscustomobject]@{
        contexts = @('Validate PR contract', 'PR CI Gate')
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
    $expectedRequiredCheckContexts = @('Validate PR contract', 'PR CI Gate', 'review')
    if ($protection.RequiredCheckContexts.Count -ne $expectedRequiredCheckContexts.Count -or @($expectedRequiredCheckContexts | Where-Object { $_ -notin $protection.RequiredCheckContexts }).Count -gt 0) {
        throw 'Branch protection required check contexts were not returned completely.'
    }
    $matchingRequiredChecks = @($expectedRequiredCheckContexts | ForEach-Object { [pscustomobject]@{ name = $_; bucket = 'pass' } })
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
    $env:JDSNACK_FAKE_REVIEWER_PERMISSION = 'pull'
    $approvalSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($approvalSummary.Count -ne 0) {
        throw 'A read-only contributor review was counted as a protected-branch human approval.'
    }
    $env:JDSNACK_FAKE_REVIEWER_PERMISSION = 'not-found'
    $nonCollaboratorSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($nonCollaboratorSummary.Count -ne 0) {
        throw 'A non-collaborator review was counted as a protected-branch human approval.'
    }
    $env:JDSNACK_FAKE_REVIEWER_PERMISSION = 'push'
    $approvalSummary = Get-HumanApprovalSummary -ExpectedHeadSha $headSha
    if ($approvalSummary.Count -ne 1 -or $approvalSummary.Logins[0] -ne 'contributor') {
        throw 'A write-level collaborator review was not counted as a current-head human approval.'
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
}


Write-Output 'Complete review approval contract tests passed'
