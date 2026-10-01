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
    currentRequester = [pscustomobject]@{ State = 'CHANGES_REQUESTED'; CommitOid = $headSha }
}
$approvers = @(Get-CurrentHeadApprovers -LatestByLogin $latestByLogin -ExpectedHeadSha $headSha)
if ($approvers.Count -ne 1 -or $approvers[0] -ne 'currentReviewer') {
    throw 'Stale approvals or non-approvals were counted for the current head.'
}

Write-Output 'Complete review approval contract tests passed'
