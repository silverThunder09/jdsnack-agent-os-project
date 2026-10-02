[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$helperPath = Join-Path $Workspace 'scripts/review-path-safety.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    throw 'Assert-NoReparsePointsInPath helper is missing.'
}
. $helperPath

$workspaceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-acl-path-safety-' + [guid]::NewGuid().ToString('N'))
$ordinaryPath = Join-Path $workspaceRoot 'ordinary'
$targetPath = Join-Path $workspaceRoot 'target'
$junctionPath = Join-Path $workspaceRoot 'linked-target'

New-Item -ItemType Directory -Path $ordinaryPath -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $targetPath 'child') -Force | Out-Null

try {
    Assert-NoReparsePointsInPath -Path $ordinaryPath

    $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $junctionPath -Target $targetPath | Out-Null

    foreach ($unsafePath in @($junctionPath, (Join-Path $junctionPath 'child'))) {
        try {
            Assert-NoReparsePointsInPath -Path $unsafePath
            throw "Expected reparse point rejection for '$unsafePath'."
        }
        catch {
            if ($_.Exception.Message -notmatch '재분석 지점') {
                throw
            }
        }
    }

    Write-Output 'Secure review ACL reparse-point contract passed'
}
finally {
    if (Test-Path -LiteralPath $junctionPath) {
        Remove-Item -LiteralPath $junctionPath -Force
    }
    if (Test-Path -LiteralPath $workspaceRoot) {
        Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
    }
}
