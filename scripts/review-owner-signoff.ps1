function Get-OwnerAutoMergeSignoff {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GhPath,

        [Parameter(Mandatory = $true)]
        [string]$Repository,

        [Parameter(Mandatory = $true)]
        [int]$PullRequestNumber,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedHeadSha
    )

    if ([string]::IsNullOrWhiteSpace($GhPath)) {
        return [pscustomobject]@{ IsValid = $false; Reason = 'GitHub CLI is unavailable.' }
    }

    $deny = {
        param([string]$Reason)
        return [pscustomobject]@{ IsValid = $false; Reason = $Reason }
    }

    $pullRequestJson = & $GhPath pr view $PullRequestNumber --repo $Repository --json state,headRefOid,autoMergeRequest 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        return (& $deny "Could not read the auto-merge request: $pullRequestJson")
    }

    try {
        $pullRequest = $pullRequestJson | ConvertFrom-Json
    } catch {
        return (& $deny 'Auto-merge request data was not valid JSON.')
    }
    if ($pullRequest.state -ne 'OPEN' -or $pullRequest.headRefOid -ne $ExpectedHeadSha) {
        return (& $deny 'The pull request is closed or its head changed after review.')
    }

    $request = $pullRequest.autoMergeRequest
    if ($null -eq $request) {
        return (& $deny 'The repository owner has not enabled auto-merge for this pull request.')
    }
    if ([string]$request.mergeMethod -ne 'SQUASH') {
        return (& $deny 'Owner confirmation must use Squash auto-merge.')
    }

    $repositoryOwner = $Repository.Split('/')[0]
    if ([string]$request.enabledBy.login -ine $repositoryOwner) {
        return (& $deny 'Only the repository owner can provide the High-risk merge confirmation.')
    }

    $enabledAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$request.enabledAt, [ref]$enabledAt)) {
        return (& $deny 'The owner auto-merge confirmation timestamp is missing or invalid.')
    }

    $commitJson = & $GhPath api "repos/$Repository/commits/$ExpectedHeadSha" 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        return (& $deny "Could not verify the reviewed head commit timestamp: $commitJson")
    }
    try {
        $commit = $commitJson | ConvertFrom-Json
    } catch {
        return (& $deny 'Reviewed head commit data was not valid JSON.')
    }
    if ($commit.sha -ne $ExpectedHeadSha) {
        return (& $deny 'GitHub returned a commit that does not match the reviewed head SHA.')
    }

    $headCommittedAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$commit.commit.committer.date, [ref]$headCommittedAt)) {
        return (& $deny 'The reviewed head commit timestamp is missing or invalid.')
    }
    if ($enabledAt -lt $headCommittedAt) {
        return (& $deny 'The owner enabled auto-merge before the latest commit; disable and re-enable Squash auto-merge to confirm this head.')
    }

    return [pscustomobject]@{
        IsValid = $true
        Reason = 'The repository owner enabled Squash auto-merge after the current head commit.'
    }
}
