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
if ($env:JDSNACK_FAKE_DISMISS_STALE -eq 'true') {
    Write-Output '{"required_pull_request_reviews":{"required_approving_review_count":2,"dismiss_stale_reviews":true}}'
} else {
    Write-Output '{"required_pull_request_reviews":{"required_approving_review_count":2,"dismiss_stale_reviews":false}}'
}
'@ | Set-Content -LiteralPath $fakeGhPath -Encoding utf8
    $script:ghPath = $fakeGhPath
    $script:Repository = 'silverThunder09/jdsnack-agent-os-project'
    $env:JDSNACK_FAKE_DISMISS_STALE = 'true'
    $protection = Get-BranchProtectionApprovalRequirement -BaseBranch 'main'
    if ([int]$protection.RequiredApprovals -ne 2 -or $protection.DismissStaleReviews -ne $true) {
        throw 'Valid branch protection was not returned as an enforced approval requirement.'
    }
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
}


Write-Output 'Complete review approval contract tests passed'
