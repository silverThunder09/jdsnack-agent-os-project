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
}

function Get-Checks {
    param([switch]$Required)

    $arguments = @('pr', 'checks', [string]$PullRequestNumber, '--repo', $Repository)
    if ($Required) {
        $arguments += '--required'
    }
    $arguments += @('--json', 'name,state,bucket')
    $checksJson = & $script:ghPath @arguments 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman "Could not read PR checks: $checksJson"
    }
    try {
        return @($checksJson | ConvertFrom-Json)
    } catch {
        Stop-NeedsHuman "PR checks returned invalid JSON: $($_.Exception.Message)"
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

$report = Get-Content -LiteralPath $ReportPath -Raw
$decisionMatch = [regex]::Match($report, '(?im)^-\s*decision:\s*(PASS)\s*$')
$scoreMatch = [regex]::Match($report, '(?im)^-\s*score:\s*([4-5])\s*/\s*5\s*$')
$riskMatch = [regex]::Match($report, '(?im)^-\s*risk:\s*(Light|Standard)\s*$')
$baseMatch = [regex]::Match($report, '(?im)^-\s*reviewed base SHA:\s*([0-9a-f]{40})\s*$')
$headMatch = [regex]::Match($report, '(?im)^-\s*reviewed head SHA:\s*([0-9a-f]{40})\s*$')
if (-not $decisionMatch.Success -or -not $scoreMatch.Success -or -not $riskMatch.Success) {
    Stop-NeedsHuman 'The review report is not an approvable PASS result with score 4 or higher and non-high risk.'
}
if (
    -not $baseMatch.Success -or
    -not $headMatch.Success -or
    $baseMatch.Groups[1].Value -ne $BaseSha -or
    $headMatch.Groups[1].Value -ne $HeadSha
) {
    Stop-NeedsHuman 'The review report does not match the reviewed base and head SHA.'
}

Assert-ReviewedPullRequestIsCurrent

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
$changedPaths = & $gitPath -C $Workspace diff --no-ext-diff --no-textconv --no-renames --name-only "$BaseSha...$HeadSha"
if ([int]$LASTEXITCODE -ne 0) {
    Stop-NeedsHuman 'Could not classify the reviewed PR paths.'
}
$highRiskPathPattern = '^(?:\.github/|\.agent-os/operations/|scripts/|(?:.*/)?AGENTS\.md$|(?:.*/)?backends\.json$|(?:.*/)?Dockerfile(?:\.[^/]*)?$|(?:.*/)?(?:docker-compose|compose)[^/]*\.ya?ml$|(?:.*/)?docker/)'
$highRiskPaths = @($changedPaths | Where-Object { $_ -match $highRiskPathPattern })
if ($highRiskPaths.Count -gt 0) {
    Stop-NeedsHuman "Deterministic path classification marked this PR High-risk: $($highRiskPaths -join ', ')"
}

$requiredChecks = Get-Checks -Required
if ($requiredChecks.Count -eq 0) {
    Stop-NeedsHuman 'No required PR checks were returned.'
}
$blockingChecks = @($requiredChecks | Where-Object { $_.bucket -ne 'pass' })
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
if ($reviewChecks.Count -ne 1 -or $reviewChecks[0].bucket -ne 'pass') {
    Stop-NeedsHuman 'The review job gate is missing, ambiguous, or not passing.'
}

# Recheck the target immediately before creating an approval for this exact commit.
Assert-ReviewedPullRequestIsCurrent
$approvalPayloadPath = Join-Path ([System.IO.Path]::GetDirectoryName($ReportPath)) 'approval-payload.json'
$approvalPayload = @{
    event = 'APPROVE'
    commit_id = $HeadSha
    body = $report
} | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText(
    $approvalPayloadPath,
    $approvalPayload,
    [System.Text.UTF8Encoding]::new($false)
)

try {
    $approvalResult = & $script:ghPath api "repos/$Repository/pulls/$PullRequestNumber/reviews" --method POST --input $approvalPayloadPath 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman "GitHub approval submission failed: $approvalResult"
    }
    try {
        $approval = $approvalResult | ConvertFrom-Json
    } catch {
        Stop-NeedsHuman 'GitHub approval response was not valid JSON.'
    }
    if ($approval.state -ne 'APPROVED' -or $approval.commit_id -ne $HeadSha) {
        Stop-NeedsHuman 'GitHub did not confirm approval for the reviewed head commit.'
    }
} finally {
    Remove-Item -LiteralPath $approvalPayloadPath -Force -ErrorAction SilentlyContinue
}

& $script:ghPath pr merge $PullRequestNumber --repo $Repository --squash --delete-branch --auto
if ([int]$LASTEXITCODE -ne 0) {
    Stop-NeedsHuman 'Approval succeeded, but auto-merge could not be queued.'
}
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
    Stop-NeedsHuman 'Auto-merge command returned but no auto-merge request was recorded.'
}

$message = "Review gates passed for PR #$PullRequestNumber at $($scoreMatch.Groups[1].Value)/5; approval was submitted for $HeadSha and auto-merge was queued."
Write-Output $message
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $message
}
