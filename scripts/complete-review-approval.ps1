param(
    [Parameter(Mandatory = $true)]
    [int]$PullRequestNumber,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$BaseSha,

    [Parameter(Mandatory = $true)]
    [string]$HeadSha,

    [string]$Workspace = $env:GITHUB_WORKSPACE,

    [string]$ReviewJobResult = '',

    [Parameter(Mandatory = $true)]
    [string]$ReportPath
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

function Stop-NeedsHuman {
    param([string]$Reason)

    $message = "JDSnack approval needs-human: $Reason"
    Write-Output $message
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $message
    }
    exit 20
}

function Assert-UniqueReviewReportFields {
    param([string]$Report)

    $requiredFields = @(
        'reviewer backend'
        'decision'
        'score'
        'risk'
        'risk score'
        'risk band'
        'review labels'
        'dry-run'
        'reviewed base SHA'
        'reviewed head SHA'
    )
    foreach ($fieldName in $requiredFields) {
        $fieldPattern = '(?im)^-[ \t]*' + [regex]::Escape($fieldName) + '[ \t]*:'
        $fieldCount = [regex]::Matches($Report, $fieldPattern).Count
        if ($fieldCount -ne 1) {
            Stop-NeedsHuman "The review report must contain exactly one '$fieldName' field."
        }
    }
}

function Test-ReviewLabelsMatchAssessment {
    param(
        [string[]]$ReportedLabels,
        [string[]]$ExpectedLabels
    )

    $reportedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($label in @($ReportedLabels | ForEach-Object { ([string]$_).Trim() })) {
        if ([string]::IsNullOrWhiteSpace($label) -or -not $reportedSet.Add($label)) {
            return $false
        }
    }
    $expectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($label in @($ExpectedLabels | ForEach-Object { ([string]$_).Trim() })) {
        if ([string]::IsNullOrWhiteSpace($label) -or -not $expectedSet.Add($label)) {
            return $false
        }
    }
    if ($reportedSet.Count -eq 0 -or $reportedSet.Count -ne $expectedSet.Count) {
        return $false
    }
    foreach ($label in $reportedSet) {
        if (-not $expectedSet.Contains($label)) {
            return $false
        }
    }
    return $true
}

function Assert-FixedApprovalPolicy {
    param([pscustomobject]$ReviewPolicy)

    if ($ReviewPolicy.dryRun -isnot [bool] -or $ReviewPolicy.dryRun -ne $true) {
        Stop-NeedsHuman 'Review policy dryRun is fixed to true for this workflow.'
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
            Stop-NeedsHuman "Review policy weight is not fixed for $weightName."
        }
    }

    $expectedBands = @(
        [pscustomobject]@{ name = 'Light'; maxScore = 30; minimumApprovals = 1; autoMerge = 'allowed-after-approval'; requiresOwnerSignoff = $false }
        [pscustomobject]@{ name = 'Standard'; maxScore = 60; minimumApprovals = 1; autoMerge = 'blocked'; requiresOwnerSignoff = $false }
        [pscustomobject]@{ name = 'High-risk'; maxScore = 100; minimumApprovals = 2; autoMerge = 'allowed-after-additional-review-and-owner-signoff'; requiresOwnerSignoff = $true }
    )
    $actualBands = @($ReviewPolicy.bands)
    if ($actualBands.Count -ne $expectedBands.Count) {
        Stop-NeedsHuman 'Review policy must define exactly three fixed risk bands.'
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
            Stop-NeedsHuman "Review policy risk band is not fixed: $($expected.name)."
        }
    }

    $canonicalPolicy = ConvertTo-Json -InputObject $ReviewPolicy -Depth 20 -Compress
    $policyBytes = [System.Text.Encoding]::UTF8.GetBytes($canonicalPolicy)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $policyDigest = (($sha256.ComputeHash($policyBytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $sha256.Dispose()
    }
    $expectedPolicyDigest = '006f215208f2951b70d946dbeb73f1ffb59e269703c290ee529e57906096ffc4'
    if ($policyDigest -ne $expectedPolicyDigest) {
        Stop-NeedsHuman 'Review policy risk scoring and routing do not match the trusted fixed policy digest.'
    }
}

function Get-ReviewPolicy {
    param([string]$PolicyPath)

    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
        Stop-NeedsHuman "Review policy file is missing: $PolicyPath"
    }
    try {
        $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
    } catch {
        Stop-NeedsHuman "Review policy is invalid JSON: $($_.Exception.Message)"
    }
    if ([int]$policy.version -ne 1) {
        Stop-NeedsHuman "Unsupported review policy version: $($policy.version)"
    }
    Assert-FixedApprovalPolicy -ReviewPolicy $policy
    return $policy
}

function Get-CurrentPullRequest {
    $pullRequestJson = & $script:ghPath api "repos/$Repository/pulls/$PullRequestNumber" 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman "Could not read the current pull request: $pullRequestJson"
    }
    try {
        return $pullRequestJson | ConvertFrom-Json
    } catch {
        Stop-NeedsHuman "Current pull request returned invalid JSON: $($_.Exception.Message)"
    }
}

function Assert-ReviewedPullRequestIsCurrent {
    $pullRequest = Get-CurrentPullRequest
    if ($pullRequest.state -ne 'open') {
        Stop-NeedsHuman 'The pull request is no longer open.'
    }
    if ($pullRequest.base.repo.full_name -ne $Repository -or $pullRequest.head.repo.full_name -ne $Repository) {
        Stop-NeedsHuman 'The pull request no longer belongs wholly to the configured repository.'
    }
    if ($pullRequest.base.sha -ne $BaseSha -or $pullRequest.head.sha -ne $HeadSha) {
        Stop-NeedsHuman 'The pull request base or head changed after the review; approval was not submitted.'
    }
    return $pullRequest
}

function Get-Checks {
    param([switch]$Required)

    $arguments = @('pr', 'checks', [string]$PullRequestNumber, '--repo', $Repository)
    if ($Required) {
        $arguments += '--required'
    }
    $arguments += @('--json', 'name,state,bucket,link')
    $checksJson = & $script:ghPath @arguments 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman "Could not read PR checks: $checksJson"
    }
    try {
        $checksEnvelopeJson = '{"checks":' + $checksJson + '}'
        $checksEnvelope = ConvertFrom-Json -InputObject $checksEnvelopeJson
        $checks = @($checksEnvelope.checks)
        return ,$checks
    } catch {
        Stop-NeedsHuman "PR checks returned invalid JSON: $($_.Exception.Message)"
    }
}

function Test-CurrentRunReviewCheck {
    param(
        [pscustomobject]$Check,
        [string]$ReviewJobResult,
        [string]$WorkflowRunId,
        [string]$Repository,
        [string]$ServerUrl
    )

    if (
        $null -eq $Check -or
        $ReviewJobResult -ine 'success' -or
        [string]$Check.name -notmatch '(^| / )review$' -or
        [string]$Check.state -ine 'SUCCESS' -or
        [string]$Check.bucket -ine 'pass' -or
        $WorkflowRunId -notmatch '^\d+$' -or
        $Repository -notmatch '^[^/]+/[^/]+$'
    ) {
        return $false
    }

    [uri]$serverUri = $null
    [uri]$checkUri = $null
    if (
        -not [uri]::TryCreate($ServerUrl, [System.UriKind]::Absolute, [ref]$serverUri) -or
        -not [uri]::TryCreate([string]$Check.link, [System.UriKind]::Absolute, [ref]$checkUri) -or
        $checkUri.Scheme -ine $serverUri.Scheme -or
        $checkUri.Authority -ine $serverUri.Authority
    ) {
        return $false
    }

    $serverPath = $serverUri.AbsolutePath.TrimEnd('/')
    $expectedRunPath = '{0}/{1}/actions/runs/{2}' -f $serverPath, $Repository.Trim('/'), $WorkflowRunId
    $actualPath = [uri]::UnescapeDataString($checkUri.AbsolutePath)
    return $actualPath.Equals($expectedRunPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        $actualPath.StartsWith($expectedRunPath + '/', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-BranchProtectionApprovalRequirement {
    param([string]$BaseBranch)

    if ([string]::IsNullOrWhiteSpace($BaseBranch)) {
        Stop-NeedsHuman 'The pull request base branch is unavailable while verifying branch protection.'
    }
    $encodedBaseBranch = [uri]::EscapeDataString($BaseBranch)
    $protectionJson = & $script:ghPath api "repos/$Repository/branches/$encodedBaseBranch/protection" 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman "Could not read effective branch protection for '$BaseBranch': $protectionJson"
    }
    try {
        $protection = ConvertFrom-Json -InputObject $protectionJson
    } catch {
        Stop-NeedsHuman "Branch protection returned invalid JSON: $($_.Exception.Message)"
    }
    $requiredReviews = $protection.required_pull_request_reviews
    if ($null -eq $requiredReviews) {
        Stop-NeedsHuman "Branch '$BaseBranch' has no required pull request review protection."
    }
    $requiredApprovals = [int]$requiredReviews.required_approving_review_count
    if ($requiredApprovals -lt 1) {
        Stop-NeedsHuman "Branch '$BaseBranch' requires fewer than one approving review."
    }
    $dismissStaleReviews = [bool]$requiredReviews.dismiss_stale_reviews
    if (-not $dismissStaleReviews) {
        Stop-NeedsHuman "Branch '$BaseBranch' does not dismiss stale pull request reviews."
    }
    $requiredStatusChecks = $protection.required_status_checks
    if ($null -eq $requiredStatusChecks) {
        Stop-NeedsHuman "Branch '$BaseBranch' has no required status check protection."
    }
    $requiredCheckContexts = @()
    foreach ($context in @($requiredStatusChecks.contexts | Where-Object { $null -ne $_ })) {
        $contextName = [string]$context
        if ([string]::IsNullOrWhiteSpace($contextName)) {
            Stop-NeedsHuman "Branch '$BaseBranch' contains an empty required status check context."
        }
        $requiredCheckContexts += $contextName
    }
    foreach ($check in @($requiredStatusChecks.checks | Where-Object { $null -ne $_ })) {
        $contextName = [string]$check.context
        if ([string]::IsNullOrWhiteSpace($contextName)) {
            Stop-NeedsHuman "Branch '$BaseBranch' contains an invalid required status check entry."
        }
        $requiredCheckContexts += $contextName
    }
    $requiredCheckContexts = @($requiredCheckContexts | Sort-Object -Unique)
    if ($requiredCheckContexts.Count -eq 0) {
        Stop-NeedsHuman "Branch '$BaseBranch' has an empty required status check set."
    }
    return [pscustomobject]@{
        RequiredApprovals = $requiredApprovals
        DismissStaleReviews = $dismissStaleReviews
        RequiredCheckContexts = $requiredCheckContexts
    }
}

function Assert-RequiredChecksMatchBranchProtection {
    param(
        [string[]]$ExpectedContexts,
        [object[]]$RequiredChecks
    )

    $expected = @($ExpectedContexts | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($expected.Count -eq 0) {
        Stop-NeedsHuman 'Branch protection did not provide any required check contexts.'
    }
    $reportedNames = @()
    foreach ($requiredCheck in @($RequiredChecks)) {
        if ($null -eq $requiredCheck -or $null -eq $requiredCheck.PSObject.Properties['name']) {
            Stop-NeedsHuman 'gh pr checks --required returned an empty or malformed check name.'
        }
        $reportedName = [string]$requiredCheck.name
        if ([string]::IsNullOrWhiteSpace($reportedName)) {
            Stop-NeedsHuman 'gh pr checks --required returned an empty or malformed check name.'
        }
        $reportedBucket = [string]$requiredCheck.bucket
        if ($reportedBucket -ine 'pass') {
            Stop-NeedsHuman "Branch-required check '$reportedName' is not passing (bucket=$reportedBucket)."
        }
        $reportedNames += $reportedName
    }
    $reported = @($reportedNames | Sort-Object -Unique)
    $missing = @($expected | Where-Object { $_ -notin $reported })
    $unexpected = @($reported | Where-Object { $_ -notin $expected })
    if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
        $missingSummary = if ($missing.Count -gt 0) { $missing -join ', ' } else { '<none>' }
        $unexpectedSummary = if ($unexpected.Count -gt 0) { $unexpected -join ', ' } else { '<none>' }
        Stop-NeedsHuman "Branch protection required check set does not match gh pr checks --required (missing: $missingSummary; unexpected: $unexpectedSummary)."
    }
}

function Get-CurrentHeadApprovers {
    param(
        [hashtable]$LatestByLogin,
        [string]$ExpectedHeadSha
    )

    return @($LatestByLogin.Keys | Where-Object {
        $latest = $LatestByLogin[$_]
        $latest.State -eq 'APPROVED' -and $latest.CommitOid -eq $ExpectedHeadSha
    } | Sort-Object)
}

function Test-EligibleHumanApprover {
    param([string]$Login)

    if ([string]::IsNullOrWhiteSpace($Login)) {
        Stop-NeedsHuman 'Human review data is missing a reviewer login while verifying repository permission.'
    }
    $encodedLogin = [uri]::EscapeDataString($Login)
    $permissionJson = & $script:ghPath api "repos/$Repository/collaborators/$encodedLogin/permission" 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        # GitHub returns HTTP 404 when the reviewer is not a repository collaborator.
        # That review is valid evidence, but it must not satisfy the protected-branch approval count.
        if ($permissionJson -match '(?i)\bHTTP\s+404\b') {
            return $false
        }
        Stop-NeedsHuman "Could not verify repository permission for reviewer '$Login': $permissionJson"
    }
    try {
        $permissionResponse = ConvertFrom-Json -InputObject $permissionJson
        $permission = [string]$permissionResponse.permission
    } catch {
        Stop-NeedsHuman "Reviewer permission returned invalid JSON for '$Login': $($_.Exception.Message)"
    }
    if ([string]::IsNullOrWhiteSpace($permission)) {
        Stop-NeedsHuman "Reviewer permission is missing for '$Login'."
    }
    return $permission -in @('admin', 'maintain', 'push')
}

function Get-HumanApprovalSummary {
    param(
        [string]$ExpectedHeadSha
    )

    $repositoryParts = $Repository -split '/'
    if ($repositoryParts.Count -ne 2) {
        Stop-NeedsHuman "Repository identity is invalid while reading human approvals: $Repository"
    }
    $graphqlQuery = @'
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      author { login }
      reviews(first: 100, after: $cursor) {
        nodes {
          author { login }
          authorAssociation
          commit { oid }
          databaseId
          id
          state
          submittedAt
          createdAt
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'@
    $cursor = $null
    $reviews = @()
    $pullRequestAuthor = ''
    do {
        $graphqlArguments = @(
            'api',
            'graphql',
            '-f', "query=$graphqlQuery",
            '-F', "owner=$($repositoryParts[0])",
            '-F', "name=$($repositoryParts[1])",
            '-F', "number=$PullRequestNumber"
        )
        if ($null -eq $cursor) {
            $graphqlArguments += @('-F', 'cursor=null')
        } else {
            $graphqlArguments += @('-F', "cursor=$cursor")
        }
        $reviewPageJson = & $script:ghPath @graphqlArguments 2>&1 | Out-String
        if ([int]$LASTEXITCODE -ne 0) {
            Stop-NeedsHuman "Could not read human approvals: $reviewPageJson"
        }
        try {
            $reviewPage = ConvertFrom-Json -InputObject $reviewPageJson
        } catch {
            Stop-NeedsHuman "Human review data returned invalid JSON: $($_.Exception.Message)"
        }
        if ($null -ne $reviewPage.errors -and @($reviewPage.errors).Count -gt 0) {
            Stop-NeedsHuman "Human review data returned GraphQL errors: $(($reviewPage.errors | ForEach-Object { $_.message }) -join '; ')"
        }
        $pullRequest = $reviewPage.data.repository.pullRequest
        if ($null -eq $pullRequest -or $null -eq $pullRequest.reviews -or $null -eq $pullRequest.reviews.pageInfo) {
            Stop-NeedsHuman 'Human review data did not include a complete reviews page.'
        }
        if ([string]::IsNullOrWhiteSpace($pullRequestAuthor)) {
            $pullRequestAuthor = [string]$pullRequest.author.login
        }
        $reviews += @($pullRequest.reviews.nodes)
        $pageInfo = $pullRequest.reviews.pageInfo
        if ([bool]$pageInfo.hasNextPage) {
            $nextCursor = [string]$pageInfo.endCursor
            if ([string]::IsNullOrWhiteSpace($nextCursor) -or $nextCursor -eq $cursor) {
                Stop-NeedsHuman 'Human review pagination did not provide a deterministic next cursor.'
            }
            $cursor = $nextCursor
        }
    } while ([bool]$pageInfo.hasNextPage)

    $latestByLogin = @{}
    $reviewEvents = @()
    foreach ($review in @($reviews)) {
        $login = [string]$review.author.login
        if ([string]::IsNullOrWhiteSpace($login) -or $login -eq $pullRequestAuthor -or $login -match '\[bot\]$') {
            continue
        }
        # authorAssociation does not prove a reviewer's current repository permission.
        # It can be CONTRIBUTOR, FIRST_TIMER, FIRST_TIME_CONTRIBUTOR, or NONE for a human.
        # Deleted mannequin identities are excluded here; write-level collaborator status is checked below.
        if ([string]$review.authorAssociation -eq 'MANNEQUIN') {
            continue
        }
        $reviewState = [string]$review.state
        $reviewId = [string]$review.id
        if ([string]::IsNullOrWhiteSpace($reviewId)) {
            $reviewId = [string]$review.databaseId
        }
        if ([string]::IsNullOrWhiteSpace($reviewId)) {
            Stop-NeedsHuman "Human review data is missing a deterministic review id for '$login'."
        }
        $reviewTimestampValue = [string]$review.submittedAt
        if ([string]::IsNullOrWhiteSpace($reviewTimestampValue)) {
            # Pending reviews have no submittedAt; createdAt must still supersede an older approval.
            $reviewTimestampValue = [string]$review.createdAt
        }
        if ([string]::IsNullOrWhiteSpace($reviewTimestampValue)) {
            Stop-NeedsHuman "Human review data is missing a submittedAt and createdAt timestamp for '$login'."
        }
        try {
            $reviewTimestamp = [datetime]::Parse($reviewTimestampValue).ToUniversalTime()
        } catch {
            Stop-NeedsHuman "Human review data has an invalid timestamp for '$login'."
        }
        $reviewEvent = [pscustomobject]@{
            Login = $login
            State = $reviewState
            Timestamp = $reviewTimestamp
            ReviewId = $reviewId
            CommitOid = [string]$review.commit.oid
        }
        $reviewEvents += $reviewEvent
        $isNewer = $false
        if (-not $latestByLogin.ContainsKey($login)) {
            $isNewer = $true
        } else {
            $existing = $latestByLogin[$login]
            $timeComparison = $reviewTimestamp.CompareTo($existing.Timestamp)
            if ($timeComparison -eq 0 -and ($reviewState -ne [string]$existing.State -or [string]$review.commit.oid -ne [string]$existing.CommitOid)) {
                Stop-NeedsHuman "Human review data has conflicting states or commits at the same timestamp for '$login'."
            }
            $idComparison = [string]::CompareOrdinal($reviewId, [string]$existing.ReviewId)
            $isNewer = $timeComparison -gt 0 -or ($timeComparison -eq 0 -and $idComparison -gt 0)
        }
        if ($isNewer) {
            $latestByLogin[$login] = $reviewEvent
        }
    }

    $eligibleLatestByLogin = @{}
    $eligibleHumanByLogin = @{}
    foreach ($login in @($latestByLogin.Keys | Sort-Object)) {
        $latestReview = $latestByLogin[$login]
        if ($latestReview.State -notin @('APPROVED', 'CHANGES_REQUESTED')) {
            continue
        }
        $eligibleHumanByLogin[$login] = Test-EligibleHumanApprover -Login $login
        if ($eligibleHumanByLogin[$login]) {
            $eligibleLatestByLogin[$login] = $latestReview
        }
    }

    $approvedLogins = @(Get-CurrentHeadApprovers -LatestByLogin $eligibleLatestByLogin -ExpectedHeadSha $ExpectedHeadSha)
    # GitHub keeps CHANGES_REQUESTED blocking across new commits until that
    # reviewer approves the current head or an authorized user dismisses it.
    # COMMENTED, PENDING, and approvals on stale commits do not resolve it.
    $changeRequestEvents = @($reviewEvents | Where-Object {
        $_.State -eq 'CHANGES_REQUESTED' -or
        $_.State -eq 'DISMISSED' -or
        ($_.State -eq 'APPROVED' -and $_.CommitOid -eq $ExpectedHeadSha)
    } | Sort-Object -Property @{
        Expression = 'Timestamp'
        Ascending = $true
    }, @{
        Expression = 'ReviewId'
        Ascending = $true
    })
    $latestChangeRequestEventByLogin = @{}
    foreach ($reviewEvent in $changeRequestEvents) {
        $latestChangeRequestEventByLogin[$reviewEvent.Login] = $reviewEvent
    }

    $changesRequestedLogins = @()
    foreach ($login in @($latestChangeRequestEventByLogin.Keys | Sort-Object)) {
        if ($latestChangeRequestEventByLogin[$login].State -ne 'CHANGES_REQUESTED') {
            continue
        }
        if (-not $eligibleHumanByLogin.ContainsKey($login)) {
            $eligibleHumanByLogin[$login] = Test-EligibleHumanApprover -Login $login
        }
        if ($eligibleHumanByLogin[$login]) {
            $changesRequestedLogins += $login
        }
    }
    return [pscustomobject]@{
        Count = $approvedLogins.Count
        Logins = $approvedLogins
        ChangesRequested = $changesRequestedLogins
    }
}

function Assert-NoUnresolvedChangeRequests {
    param([pscustomobject]$ApprovalSummary)

    $changesRequested = @($ApprovalSummary.ChangesRequested)
    if ($changesRequested.Count -gt 0) {
        Stop-NeedsHuman "Unresolved human change request(s) remain: $($changesRequested -join ', ')."
    }
}

function Assert-MinimumHumanApprovalCount {
    param(
        [int]$ActualApprovals,
        [int]$RiskMinimumApprovals,
        [int]$BranchProtectionMinimumApprovals,
        [string]$RiskBand
    )

    $effectiveMinimumApprovals = [Math]::Max($RiskMinimumApprovals, $BranchProtectionMinimumApprovals)
    if ($ActualApprovals -lt $effectiveMinimumApprovals) {
        Stop-NeedsHuman "Risk band $RiskBand and branch protection require at least $effectiveMinimumApprovals human approval(s); found $ActualApprovals."
    }
}

if ($PullRequestNumber -le 0 -or $Repository -notmatch '^[^/]+/[^/]+$') {
    Stop-NeedsHuman 'Pull request identity is invalid.'
}
foreach ($targetSha in @($BaseSha, $HeadSha)) {
    if ($targetSha -notmatch '^[0-9a-fA-F]{40}$') {
        Stop-NeedsHuman "A full 40-character reviewed SHA is required: $targetSha"
    }
}
$script:ghPath = Resolve-ToolPath 'gh'
if ([string]::IsNullOrWhiteSpace($script:ghPath)) {
    Stop-NeedsHuman 'GitHub CLI is unavailable.'
}
if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    Stop-NeedsHuman 'The review report artifact is missing.'
}
if ([string]::IsNullOrWhiteSpace($Workspace) -or -not (Test-Path -LiteralPath $Workspace -PathType Container)) {
    Stop-NeedsHuman 'The trusted approval workspace is unavailable.'
}
$ownerSignoffPath = Join-Path $Workspace 'scripts/review-owner-signoff.ps1'
if (-not (Test-Path -LiteralPath $ownerSignoffPath -PathType Leaf)) {
    Stop-NeedsHuman 'The trusted owner signoff verifier is unavailable.'
}
. $ownerSignoffPath
$policyPath = Join-Path $Workspace 'scripts/review-policy.json'
$reviewPolicy = Get-ReviewPolicy $policyPath

$report = Get-Content -LiteralPath $ReportPath -Raw
Assert-UniqueReviewReportFields -Report $report
$reviewerBackendMatch = [regex]::Match($report, '(?im)^-\s*reviewer backend:\s*([^\r\n]+)$')
$decisionMatch = [regex]::Match($report, '(?im)^-\s*decision:\s*(PASS)\s*$')
$scoreMatch = [regex]::Match($report, '(?im)^-\s*score:\s*([4-5])\s*/\s*5\s*$')
$riskMatch = [regex]::Match($report, '(?im)^-\s*risk:\s*(Light|Standard|High-risk)\s*$')
$riskScoreMatch = [regex]::Match($report, '(?im)^-\s*risk score:\s*(\d+)\s*/\s*100\s*$')
$riskBandMatch = [regex]::Match($report, '(?im)^-\s*risk band:\s*(Light|Standard|High-risk)\s*$')
$reviewLabelsMatch = [regex]::Match($report, '(?im)^-\s*review labels:\s*([^\r\n]+?)\s*$')
$dryRunMatch = [regex]::Match($report, '(?im)^-\s*dry-run:\s*(True|False)\s*$')
$baseMatch = [regex]::Match($report, '(?im)^-\s*reviewed base SHA:\s*([0-9a-f]{40})\s*$')
$headMatch = [regex]::Match($report, '(?im)^-\s*reviewed head SHA:\s*([0-9a-f]{40})\s*$')
if (-not $reviewerBackendMatch.Success -or -not $decisionMatch.Success -or -not $scoreMatch.Success -or -not $riskMatch.Success) {
    Stop-NeedsHuman 'The review report must have a PASS result with score 4 or higher.'
}
if (-not $riskScoreMatch.Success -or -not $riskBandMatch.Success -or -not $reviewLabelsMatch.Success -or -not $dryRunMatch.Success) {
    Stop-NeedsHuman 'The review report must include deterministic risk score, risk band, labels, and dry-run state.'
}
if (
    -not $baseMatch.Success -or
    -not $headMatch.Success -or
    $baseMatch.Groups[1].Value -ne $BaseSha -or
    $headMatch.Groups[1].Value -ne $HeadSha
) {
    Stop-NeedsHuman 'The review report does not match the reviewed base and head SHA.'
}

$currentPullRequest = Assert-ReviewedPullRequestIsCurrent

$gitPath = Resolve-ToolPath 'git'
if ([string]::IsNullOrWhiteSpace($gitPath)) {
    Stop-NeedsHuman 'Git is unavailable for deterministic risk verification.'
}
foreach ($sha in @($BaseSha, $HeadSha)) {
    & $gitPath -C $Workspace fetch --no-tags origin $sha 2>&1 | Out-Null
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman "Could not fetch reviewed commit $sha for risk verification."
    }
}
$riskScriptPath = Join-Path $Workspace 'scripts/review-risk.ps1'
if (-not (Test-Path -LiteralPath $riskScriptPath -PathType Leaf)) {
    Stop-NeedsHuman "Deterministic review risk calculator is missing: $riskScriptPath"
}
$riskJson = (& $riskScriptPath -Workspace $Workspace -BaseSha $BaseSha -HeadSha $HeadSha | Out-String)
if ([int]$LASTEXITCODE -ne 0) {
    Stop-NeedsHuman 'Deterministic review risk calculation failed.'
}
try {
    $riskAssessment = ConvertFrom-Json -InputObject $riskJson
} catch {
    Stop-NeedsHuman "Deterministic review risk calculation returned invalid JSON: $($_.Exception.Message)"
}
if ($riskMatch.Groups[1].Value -ne [string]$riskAssessment.riskBand) {
    Stop-NeedsHuman 'The review report risk field does not match the deterministic risk band.'
}
if (
    [int]$riskScoreMatch.Groups[1].Value -ne [int]$riskAssessment.riskScore -or
    $riskBandMatch.Groups[1].Value -ne [string]$riskAssessment.riskBand -or
    -not (Test-ReviewLabelsMatchAssessment `
        -ReportedLabels @($reviewLabelsMatch.Groups[1].Value -split ',') `
        -ExpectedLabels @($riskAssessment.reviewLabels)) -or
    ([string]$dryRunMatch.Groups[1].Value -eq 'True') -ne [bool]$riskAssessment.dryRun
) {
    Stop-NeedsHuman 'The review report risk data and labels do not match the deterministic assessment.'
}

$branchProtectionApproval = Get-BranchProtectionApprovalRequirement -BaseBranch ([string]$currentPullRequest.base.ref)
$requiredChecks = Get-Checks -Required
if ($requiredChecks.Count -eq 0) {
    Stop-NeedsHuman 'No required PR checks were returned.'
}
Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $branchProtectionApproval.RequiredCheckContexts -RequiredChecks $requiredChecks
$blockingChecks = @($requiredChecks | Where-Object { $_.bucket -ine 'pass' })
if ($blockingChecks.Count -gt 0) {
    $blockingSummary = ($blockingChecks | ForEach-Object { '{0}={1}' -f $_.name, $_.bucket }) -join ', '
    Stop-NeedsHuman "Required checks are not passing: $blockingSummary"
}

$allChecks = Get-Checks
foreach ($gateName in @('Validate PR contract', 'PR CI Gate')) {
    $gateChecks = @($allChecks | Where-Object { $_.name -eq $gateName })
    if ($gateChecks.Count -ne 1 -or $gateChecks[0].bucket -ne 'pass') {
        Stop-NeedsHuman "PR gate '$gateName' is missing, ambiguous, or not passing."
    }
}
$reviewChecks = @($allChecks | Where-Object { $_.name -eq 'review' -or $_.name -match '(^| / )review$' })
$reviewCheckAccepted = $reviewChecks.Count -eq 1 -and (
    $reviewChecks[0].bucket -eq 'pass' -or
    (Test-CurrentRunReviewCheck `
        -Check $reviewChecks[0] `
        -ReviewJobResult $ReviewJobResult `
        -WorkflowRunId $env:GITHUB_RUN_ID `
        -Repository $Repository `
        -ServerUrl $env:GITHUB_SERVER_URL)
)
if (-not $reviewCheckAccepted) {
    Stop-NeedsHuman 'The review job gate is missing, ambiguous, or not passing.'
}

if ($reviewerBackendMatch.Groups[1].Value.Trim() -eq 'codex-fallback') {
    Stop-NeedsHuman 'Implementation and reviewer backend are both Codex fallback; automatic merge is disabled for self-review prevention.'
}

$approvalSummary = Get-HumanApprovalSummary -ExpectedHeadSha $HeadSha
# This assertion intentionally precedes the dry-run success path.
Assert-NoUnresolvedChangeRequests -ApprovalSummary $approvalSummary
Assert-MinimumHumanApprovalCount `
    -ActualApprovals $approvalSummary.Count `
    -RiskMinimumApprovals ([int]$riskAssessment.minimumApprovals) `
    -BranchProtectionMinimumApprovals ([int]$branchProtectionApproval.RequiredApprovals) `
    -RiskBand $riskAssessment.riskBand

if ([bool]$riskAssessment.dryRun) {
    $message = "Review gates passed for PR #$PullRequestNumber at $($scoreMatch.Groups[1].Value)/5; $($riskAssessment.riskBand) has the required human approval(s), dry-run is enabled, and no merge command was executed."
    Write-Output $message
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $message
    }
    exit 0
}

if ([string]$riskAssessment.autoMergePolicy -eq 'blocked') {
    Stop-NeedsHuman "Automatic merge is blocked by policy for risk band $($riskAssessment.riskBand); the approval gate will not report success for this merge policy."
}
if ([bool]$riskAssessment.requiresOwnerSignoff) {
    $signoff = Get-OwnerAutoMergeSignoff `
        -GhPath $script:ghPath `
        -Repository $Repository `
        -PullRequestNumber $PullRequestNumber `
        -ExpectedHeadSha $HeadSha
    if (-not $signoff.IsValid) {
        Stop-NeedsHuman "High-risk change lacks current-head Squash auto-merge confirmation: $($signoff.Reason)"
    }
}

# Recheck the target immediately before queueing Squash auto-merge for this exact commit.
[void](Assert-ReviewedPullRequestIsCurrent)
$mergeStateJson = & $script:ghPath pr view $PullRequestNumber --repo $Repository --json state,autoMergeRequest,mergeStateStatus
if ([int]$LASTEXITCODE -ne 0) {
    Stop-NeedsHuman 'Could not verify auto-merge state after approval.'
}
try {
    $mergeState = $mergeStateJson | ConvertFrom-Json
} catch {
    Stop-NeedsHuman 'Auto-merge verification returned invalid JSON.'
}
if ($mergeState.state -ne 'MERGED' -and $null -eq $mergeState.autoMergeRequest) {
    & $script:ghPath pr merge $PullRequestNumber --repo $Repository --squash --delete-branch --auto
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman 'Review gates passed, but Squash auto-merge could not be queued.'
    }
    $mergeStateJson = & $script:ghPath pr view $PullRequestNumber --repo $Repository --json state,autoMergeRequest,mergeStateStatus
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman 'Could not verify Squash auto-merge state after queueing.'
    }
    try {
        $mergeState = $mergeStateJson | ConvertFrom-Json
    } catch {
        Stop-NeedsHuman 'Squash auto-merge verification returned invalid JSON.'
    }
}
if ($mergeState.state -ne 'MERGED' -and $mergeState.autoMergeRequest.mergeMethod -ne 'SQUASH') {
    Stop-NeedsHuman 'The existing auto-merge request is not configured for Squash.'
}

$message = "Review gates passed for PR #$PullRequestNumber at $($scoreMatch.Groups[1].Value)/5; Squash auto-merge is queued for $HeadSha."
Write-Output $message
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $message
}
