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
        $checksEnvelopeJson = '{"checks":' + $checksJson + '}'
        $checksEnvelope = ConvertFrom-Json -InputObject $checksEnvelopeJson
        $checks = @($checksEnvelope.checks)
        return ,$checks
    } catch {
        Stop-NeedsHuman "PR checks returned invalid JSON: $($_.Exception.Message)"
    }
}

function Get-HumanApprovalSummary {
    $reviewJson = & $script:ghPath pr view $PullRequestNumber --repo $Repository --json author,reviews 2>&1 | Out-String
    if ([int]$LASTEXITCODE -ne 0) {
        Stop-NeedsHuman "Could not read human approvals: $reviewJson"
    }
    try {
        $reviewData = ConvertFrom-Json -InputObject $reviewJson
    } catch {
        Stop-NeedsHuman "Human review data returned invalid JSON: $($_.Exception.Message)"
    }

    $pullRequestAuthor = [string]$reviewData.author.login
    $latestByLogin = @{}
    foreach ($review in @($reviewData.reviews)) {
        $login = [string]$review.author.login
        if ([string]::IsNullOrWhiteSpace($login) -or $login -eq $pullRequestAuthor -or $login -match '\[bot\]$') {
            continue
        }
        $submittedAt = [datetime]::MinValue
        if (-not [string]::IsNullOrWhiteSpace([string]$review.submittedAt)) {
            try { $submittedAt = [datetime]::Parse([string]$review.submittedAt) } catch { }
        }
        if (-not $latestByLogin.ContainsKey($login) -or $submittedAt -gt $latestByLogin[$login].SubmittedAt) {
            $latestByLogin[$login] = [pscustomobject]@{
                State = [string]$review.state
                SubmittedAt = $submittedAt
            }
        }
    }

    $approvedLogins = @($latestByLogin.Keys | Where-Object { $latestByLogin[$_].State -eq 'APPROVED' } | Sort-Object)
    return [pscustomobject]@{
        Count = $approvedLogins.Count
        Logins = $approvedLogins
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
$reviewerBackendMatch = [regex]::Match($report, '(?im)^-\s*reviewer backend:\s*([^\r\n]+)$')
$decisionMatch = [regex]::Match($report, '(?im)^-\s*decision:\s*(PASS)\s*$')
$scoreMatch = [regex]::Match($report, '(?im)^-\s*score:\s*([4-5])\s*/\s*5\s*$')
$riskMatch = [regex]::Match($report, '(?im)^-\s*risk:\s*(Light|Standard|High-risk)\s*$')
$riskScoreMatch = [regex]::Match($report, '(?im)^-\s*risk score:\s*(\d+)\s*/\s*100\s*$')
$riskBandMatch = [regex]::Match($report, '(?im)^-\s*risk band:\s*(Light|Standard|High-risk)\s*$')
$dryRunMatch = [regex]::Match($report, '(?im)^-\s*dry-run:\s*(True|False)\s*$')
$baseMatch = [regex]::Match($report, '(?im)^-\s*reviewed base SHA:\s*([0-9a-f]{40})\s*$')
$headMatch = [regex]::Match($report, '(?im)^-\s*reviewed head SHA:\s*([0-9a-f]{40})\s*$')
if (-not $reviewerBackendMatch.Success -or -not $decisionMatch.Success -or -not $scoreMatch.Success -or -not $riskMatch.Success) {
    Stop-NeedsHuman 'The review report must have a PASS result with score 4 or higher.'
}
if (-not $riskScoreMatch.Success -or -not $riskBandMatch.Success -or -not $dryRunMatch.Success) {
    Stop-NeedsHuman 'The review report must include deterministic risk score, risk band, and dry-run state.'
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
    ([string]$dryRunMatch.Groups[1].Value -eq 'True') -ne [bool]$riskAssessment.dryRun
) {
    Stop-NeedsHuman 'The review report risk data does not match the deterministic assessment.'
}

$requiredChecks = Get-Checks -Required
if ($requiredChecks.Count -eq 0) {
    Stop-NeedsHuman 'No required PR checks were returned.'
}
$blockingChecks = @($requiredChecks | Where-Object { $_.bucket -notin @('pass', 'skipping') })
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

if ([bool]$riskAssessment.dryRun) {
    $message = "Review gates passed for PR #$PullRequestNumber at $($scoreMatch.Groups[1].Value)/5; dry-run is enabled, so no merge command was executed."
    Write-Output $message
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $message
    }
    exit 0
}

if ($reviewerBackendMatch.Groups[1].Value.Trim() -eq 'codex-fallback') {
    Stop-NeedsHuman 'Implementation and reviewer backend are both Codex fallback; automatic merge is disabled for self-review prevention.'
}

$approvalSummary = Get-HumanApprovalSummary
if ($approvalSummary.Count -lt [int]$riskAssessment.minimumApprovals) {
    Stop-NeedsHuman "Risk band $($riskAssessment.riskBand) requires at least $($riskAssessment.minimumApprovals) human approval(s); found $($approvalSummary.Count)."
}
if ([string]$riskAssessment.autoMergePolicy -eq 'blocked') {
    Stop-NeedsHuman "Risk band $($riskAssessment.riskBand) requires human review and blocks automatic merge."
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
Assert-ReviewedPullRequestIsCurrent
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
