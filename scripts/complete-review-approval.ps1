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

function Invoke-NativeCommandWithExitCode {
    param(
        [string]$ExecutablePath,
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $ExecutablePath @Arguments 2>&1 | Out-Null
        $exitCode = [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return $exitCode
}

$prCheckPolicyPath = Join-Path $Workspace 'scripts/pr-check-policy.ps1'
if (-not (Test-Path -LiteralPath $prCheckPolicyPath -PathType Leaf)) {
    Stop-NeedsHuman "Conditional PR check policy is missing: $prCheckPolicyPath"
}
. $prCheckPolicyPath

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

function Get-ReviewReportFieldMatch {
    param(
        [string]$Report,
        [string]$FieldName,
        [string]$ValuePattern
    )

    $fieldPattern = '(?im)^-\s*{0}:\s*{1}\s*$' -f [regex]::Escape($FieldName), $ValuePattern
    return [regex]::Match($Report, $fieldPattern)
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

    if ([string]$ReviewPolicy.primaryReviewer -notin @('claude', 'codex')) {
        Stop-NeedsHuman 'Review policy primaryReviewer must be claude or codex.'
    }
    if ($ReviewPolicy.dryRun -isnot [bool] -or $ReviewPolicy.dryRun -ne $false) {
        Stop-NeedsHuman 'Review policy dryRun must be false to enable score-based auto-merge.'
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
        [pscustomobject]@{ name = 'Light'; maxScore = 30; minimumApprovals = 0; autoMerge = 'allowed-after-passing-review-and-required-checks'; requiresOwnerSignoff = $false }
        [pscustomobject]@{ name = 'Standard'; maxScore = 60; minimumApprovals = 0; autoMerge = 'allowed-after-passing-review-and-required-checks'; requiresOwnerSignoff = $false }
        [pscustomobject]@{ name = 'High-risk'; maxScore = 100; minimumApprovals = 0; autoMerge = 'allowed-after-passing-review-and-required-checks'; requiresOwnerSignoff = $false }
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
    $expectedPolicyDigest = '432fd66452e680a12dc84cced3f0a53cf0aeb4ee724dac4f7cd86d3da67ee9e8'
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

function Get-ReviewCheckRunsForHead {
    param([string]$ExpectedHeadSha)

    if ($ExpectedHeadSha -notmatch '^[0-9a-fA-F]{40}$') {
        Stop-NeedsHuman 'A full current PR head SHA is required to verify the review check run.'
    }
    $apiPath = "repos/$Repository/commits/$ExpectedHeadSha/check-runs?check_name=review&per_page=100"
    $checkRunsJson = & $script:ghPath api $apiPath 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman "Could not read review check runs for the current PR head: $checkRunsJson"
    }
    try {
        $checkRunsEnvelope = ConvertFrom-Json -InputObject $checkRunsJson
    } catch {
        Stop-NeedsHuman "Review check runs returned invalid JSON: $($_.Exception.Message)"
    }
    $checkRuns = @($checkRunsEnvelope.check_runs)
    if ($null -eq $checkRunsEnvelope.total_count -or [int]$checkRunsEnvelope.total_count -ne $checkRuns.Count) {
        Stop-NeedsHuman 'Review check run results were incomplete or malformed.'
    }
    if (@($checkRuns | Where-Object { [string]$_.head_sha -ine $ExpectedHeadSha }).Count -gt 0) {
        Stop-NeedsHuman 'GitHub returned a review check run for a different PR head SHA.'
    }
    return ,@($checkRuns | Where-Object { [string]$_.name -ceq 'review' })
}

function Get-CanonicalReviewChecks {
    param([object[]]$Checks)

    $reviewChecks = @($Checks | Where-Object { [string]$_.name -ceq 'review' })
    return $reviewChecks
}

function Test-CurrentRunReviewCheck {
    param(
        [pscustomobject]$Check,
        [pscustomobject]$ReviewCheckRun,
        [string]$ReviewJobResult,
        [string]$Repository,
        [string]$ServerUrl,
        [string]$ExpectedHeadSha
    )

    if (
        $null -eq $Check -or
        $null -eq $ReviewCheckRun -or
        $ReviewJobResult -cne 'success' -or
        [string]$Check.name -cne 'review' -or
        [string]$Check.state -cne 'SUCCESS' -or
        [string]$Check.bucket -cne 'pass' -or
        $Repository -notmatch '^[^/]+/[^/]+$' -or
        $ExpectedHeadSha -notmatch '^[0-9a-fA-F]{40}$' -or
        [string]$ReviewCheckRun.name -cne 'review' -or
        [string]$ReviewCheckRun.head_sha -ine $ExpectedHeadSha -or
        [string]$ReviewCheckRun.external_id -cne ('jdsnack-review:{0}:{1}' -f $Repository, $ExpectedHeadSha) -or
        [string]$ReviewCheckRun.status -cne 'completed' -or
        [string]$ReviewCheckRun.conclusion -cne 'success'
    ) {
        return $false
    }

    [uri]$serverUri = $null
    [uri]$checkUri = $null
    [uri]$reviewCheckUri = $null
    [uri]$reviewDetailsUri = $null
    if (
        -not [uri]::TryCreate($ServerUrl, [System.UriKind]::Absolute, [ref]$serverUri) -or
        -not [uri]::TryCreate([string]$Check.link, [System.UriKind]::Absolute, [ref]$checkUri) -or
        -not [uri]::TryCreate([string]$ReviewCheckRun.html_url, [System.UriKind]::Absolute, [ref]$reviewCheckUri) -or
        $checkUri.Scheme -ine $serverUri.Scheme -or
        $checkUri.Authority -ine $serverUri.Authority -or
        $reviewCheckUri.Scheme -ine $serverUri.Scheme -or
        $reviewCheckUri.Authority -ine $serverUri.Authority
    ) {
        return $false
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$ReviewCheckRun.details_url)) {
        if (
            -not [uri]::TryCreate([string]$ReviewCheckRun.details_url, [System.UriKind]::Absolute, [ref]$reviewDetailsUri) -or
            $reviewDetailsUri.Scheme -ine $serverUri.Scheme -or
            $reviewDetailsUri.Authority -ine $serverUri.Authority
        ) {
            return $false
        }
    }

    $serverPath = $serverUri.AbsolutePath.TrimEnd('/')
    $expectedCheckPath = '{0}/{1}/runs/{2}' -f $serverPath, $Repository.Trim('/'), [string]$ReviewCheckRun.id
    $actualPath = [uri]::UnescapeDataString($checkUri.AbsolutePath)
    $reviewCheckPath = [uri]::UnescapeDataString($reviewCheckUri.AbsolutePath)
    $detailsPath = if ($null -ne $reviewDetailsUri) { [uri]::UnescapeDataString($reviewDetailsUri.AbsolutePath) } else { '' }
    $checkLinkMatchesHtml = $actualPath.Equals($reviewCheckPath, [System.StringComparison]::OrdinalIgnoreCase)
    $checkLinkMatchesDetails = -not [string]::IsNullOrWhiteSpace($detailsPath) -and
        $actualPath.Equals($detailsPath, [System.StringComparison]::OrdinalIgnoreCase)
    return $reviewCheckPath.Equals($expectedCheckPath, [System.StringComparison]::OrdinalIgnoreCase) -and
        ($checkLinkMatchesHtml -or $checkLinkMatchesDetails)
}

function Assert-CurrentRunReviewGate {
    param(
        [object[]]$Checks,
        [object[]]$ReviewCheckRuns,
        [string]$ReviewJobResult,
        [string]$Repository,
        [string]$ServerUrl,
        [string]$ExpectedHeadSha
    )

    $reviewChecks = @(Get-CanonicalReviewChecks -Checks $Checks)
    $expectedExternalId = 'jdsnack-review:{0}:{1}' -f $Repository, $ExpectedHeadSha
    $reviewCheckRunsForHead = @($ReviewCheckRuns | Where-Object {
            [string]$_.name -ceq 'review' -and
            [string]$_.head_sha -ieq $ExpectedHeadSha -and
            [string]$_.external_id -ceq $expectedExternalId
        })
    if ($reviewChecks.Count -ne 1 -or -not (Test-CurrentRunReviewCheck `
                -Check $reviewChecks[0] `
                -ReviewCheckRun $(if ($reviewCheckRunsForHead.Count -eq 1) { $reviewCheckRunsForHead[0] } else { $null }) `
                -ReviewJobResult $ReviewJobResult `
                -Repository $Repository `
                -ServerUrl $ServerUrl `
                -ExpectedHeadSha $ExpectedHeadSha)) {
        Stop-NeedsHuman 'The review job gate is missing, ambiguous, stale, for a different PR head, or not passing.'
    }
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
    if ($requiredApprovals -lt 0) {
        Stop-NeedsHuman "Branch '$BaseBranch' returned an invalid negative approval count."
    }
    $dismissStaleReviews = [bool]$requiredReviews.dismiss_stale_reviews
    if ($requiredApprovals -gt 0 -and -not $dismissStaleReviews) {
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
    $requiredCheckContexts = @($requiredCheckContexts | Sort-Object -Unique -CaseSensitive)
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

    $expected = @($ExpectedContexts | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique -CaseSensitive)
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
        # GitHub considers path-selected jobs that are conditionally skipped
        # successful, but the PR contract, router gate, and review must run.
        $successfulConditionalSkip = Test-SuccessfulConditionalPrCheckSkip `
            -CheckName $reportedName `
            -Bucket $reportedBucket
        if ($reportedBucket -cne 'pass' -and -not $successfulConditionalSkip) {
            Stop-NeedsHuman "Branch-required check '$reportedName' is not passing (bucket=$reportedBucket)."
        }
        $reportedNames += $reportedName
    }
    $reported = @($reportedNames | Sort-Object -Unique -CaseSensitive)
    $missing = @($expected | Where-Object { $_ -cnotin $reported })
    $unexpected = @($reported | Where-Object { $_ -cnotin $expected })
    if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
        $missingSummary = if ($missing.Count -gt 0) { $missing -join ', ' } else { '<none>' }
        $unexpectedSummary = if ($unexpected.Count -gt 0) { $unexpected -join ', ' } else { '<none>' }
        Stop-NeedsHuman "Branch protection required check set does not match gh pr checks --required (missing: $missingSummary; unexpected: $unexpectedSummary)."
    }
}

function Assert-RequiredPrGatesPassing {
    param([object[]]$Checks)

    foreach ($gateName in @('Validate PR contract', 'PR CI Gate')) {
        $gateChecks = @($Checks | Where-Object { [string]$_.name -ceq $gateName })
        if ($gateChecks.Count -ne 1 -or $gateChecks[0].bucket -cne 'pass') {
            Stop-NeedsHuman "PR gate '$gateName' is missing, ambiguous, or not passing."
        }
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
    return $permission -in @('admin', 'maintain', 'push', 'write')
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
$policyPath = Join-Path $Workspace 'scripts/review-policy.json'
$reviewPolicy = Get-ReviewPolicy $policyPath

$report = Get-Content -LiteralPath $ReportPath -Raw
Assert-UniqueReviewReportFields -Report $report
$reviewerBackendMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'reviewer backend' -ValuePattern '([^\r\n]+)'
$decisionMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'decision' -ValuePattern '(PASS)'
$scoreMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'score' -ValuePattern '([4-5])\s*/\s*5'
$riskMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'risk' -ValuePattern '(Light|Standard|High-risk)'
$riskScoreMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'risk score' -ValuePattern '(\d+)\s*/\s*100'
$riskBandMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'risk band' -ValuePattern '(Light|Standard|High-risk)'
$reviewLabelsMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'review labels' -ValuePattern '([^\r\n]+?)'
$baseMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'reviewed base SHA' -ValuePattern '([0-9a-f]{40})'
$headMatch = Get-ReviewReportFieldMatch -Report $report -FieldName 'reviewed head SHA' -ValuePattern '([0-9a-f]{40})'
if (-not $reviewerBackendMatch.Success -or -not $decisionMatch.Success -or -not $scoreMatch.Success -or -not $riskMatch.Success) {
    Stop-NeedsHuman 'The review report must have a PASS result with score 4 or higher.'
}
if (-not $riskScoreMatch.Success -or -not $riskBandMatch.Success -or -not $reviewLabelsMatch.Success) {
    Stop-NeedsHuman 'The review report must include deterministic risk score, risk band, and labels.'
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
    $fetchExitCode = Invoke-NativeCommandWithExitCode -ExecutablePath $gitPath -Arguments @(
        '-C', $Workspace,
        'fetch',
        '--no-tags',
        'origin',
        $sha
    )
    if ($fetchExitCode -ne 0) {
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
if (
    [int]$riskScoreMatch.Groups[1].Value -ne [int]$riskAssessment.riskScore -or
    $riskBandMatch.Groups[1].Value -ne [string]$riskAssessment.riskBand -or
    -not (Test-ReviewLabelsMatchAssessment `
        -ReportedLabels @($reviewLabelsMatch.Groups[1].Value -split ',') `
        -ExpectedLabels @($riskAssessment.reviewLabels))
) {
    Stop-NeedsHuman 'The review report label data does not match the deterministic assessment.'
}
if ($riskMatch.Groups[1].Value -ne [string]$riskAssessment.riskBand) {
    Stop-NeedsHuman 'The normalized review risk label does not match the deterministic label.'
}

$branchProtectionApproval = Get-BranchProtectionApprovalRequirement -BaseBranch ([string]$currentPullRequest.base.ref)
$requiredChecks = Get-Checks -Required
if ($requiredChecks.Count -eq 0) {
    Stop-NeedsHuman 'No required PR checks were returned.'
}
Assert-RequiredChecksMatchBranchProtection -ExpectedContexts $branchProtectionApproval.RequiredCheckContexts -RequiredChecks $requiredChecks
$blockingChecks = @($requiredChecks | Where-Object {
        [string]$_.bucket -cnotin @('pass', 'skipping')
    })
if ($blockingChecks.Count -gt 0) {
    $blockingSummary = ($blockingChecks | ForEach-Object { '{0}={1}' -f $_.name, $_.bucket }) -join ', '
    Stop-NeedsHuman "Required checks are not passing: $blockingSummary"
}

$allChecks = Get-Checks
Assert-RequiredPrGatesPassing -Checks $allChecks
$reviewCheckRuns = Get-ReviewCheckRunsForHead -ExpectedHeadSha $HeadSha
Assert-CurrentRunReviewGate `
    -Checks $allChecks `
    -ReviewCheckRuns $reviewCheckRuns `
    -ReviewJobResult $ReviewJobResult `
    -Repository $Repository `
    -ServerUrl $env:GITHUB_SERVER_URL `
    -ExpectedHeadSha $HeadSha

$approvalSummary = Get-HumanApprovalSummary -ExpectedHeadSha $HeadSha
Assert-NoUnresolvedChangeRequests -ApprovalSummary $approvalSummary
Assert-MinimumHumanApprovalCount `
    -ActualApprovals $approvalSummary.Count `
    -RiskMinimumApprovals ([int]$riskAssessment.minimumApprovals) `
    -BranchProtectionMinimumApprovals ([int]$branchProtectionApproval.RequiredApprovals) `
    -RiskBand $riskAssessment.riskBand

if ([string]$riskAssessment.autoMergePolicy -eq 'blocked') {
    Stop-NeedsHuman "Automatic merge is blocked by policy for risk band $($riskAssessment.riskBand); the approval gate will not report success for this merge policy."
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
