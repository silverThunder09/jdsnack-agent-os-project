[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AuthPath,
    [Parameter(Mandatory = $true)]
    [string]$SnapshotPath,
    [Parameter(Mandatory = $true)]
    [string]$ReplacementPath,
    [Parameter(Mandatory = $true)]
    [string]$UpdatedAuthPath
)

$ErrorActionPreference = 'Stop'

function Test-BytesEqual {
    param(
        [byte[]]$Left,
        [byte[]]$Right
    )

    if ($Left.Length -ne $Right.Length) {
        return $false
    }
    for ($index = 0; $index -lt $Left.Length; $index++) {
        if ($Left[$index] -ne $Right[$index]) {
            return $false
        }
    }
    return $true
}

$authPathFull = [System.IO.Path]::GetFullPath($AuthPath)
$snapshotPathFull = [System.IO.Path]::GetFullPath($SnapshotPath)
$replacementPathFull = [System.IO.Path]::GetFullPath($ReplacementPath)
$updatedAuthPathFull = [System.IO.Path]::GetFullPath($UpdatedAuthPath)
$authDirectory = [System.IO.Path]::GetDirectoryName($authPathFull)
$replacementDirectory = [System.IO.Path]::GetDirectoryName($replacementPathFull)
if (-not [string]::Equals($authDirectory, $replacementDirectory, [StringComparison]::OrdinalIgnoreCase)) {
    throw '인증 파일 갱신 임시 파일은 원본과 같은 디렉터리에 있어야 합니다.'
}
$backupPathFull = Join-Path $authDirectory ('.codex-auth-backup-' + [guid]::NewGuid().ToString('N'))

$snapshotBytes = [System.IO.File]::ReadAllBytes($snapshotPathFull)
$currentBytes = [System.IO.File]::ReadAllBytes($authPathFull)
if (-not (Test-BytesEqual -Left $snapshotBytes -Right $currentBytes)) {
    throw 'Codex 인증 원본이 리뷰 도중 변경되어 갱신을 적용하지 않습니다.'
}

$replacementItem = Get-Item -LiteralPath $replacementPathFull
if ($replacementItem.Length -ne 0) {
    throw 'Codex 인증 갱신 임시 파일이 비어 있지 않습니다.'
}

$sourceAcl = Get-Acl -LiteralPath $authPathFull
$replacementAcl = Get-Acl -LiteralPath $replacementPathFull
$sourceAccessDescriptor = $sourceAcl.GetSecurityDescriptorSddlForm(
    [System.Security.AccessControl.AccessControlSections]::Access
)
$replacementAcl.SetSecurityDescriptorSddlForm(
    $sourceAccessDescriptor,
    [System.Security.AccessControl.AccessControlSections]::Access
)
Set-Acl -LiteralPath $replacementPathFull -AclObject $replacementAcl

$replacementAcl = Get-Acl -LiteralPath $replacementPathFull
if ($replacementAcl.GetSecurityDescriptorSddlForm(
    [System.Security.AccessControl.AccessControlSections]::Access
) -cne $sourceAccessDescriptor) {
    throw 'Codex 인증 갱신 임시 파일의 ACL을 원본과 동일하게 제한하지 못했습니다.'
}

$updatedBytes = [System.IO.File]::ReadAllBytes($updatedAuthPathFull)
[System.IO.File]::WriteAllBytes($replacementPathFull, $updatedBytes)

$currentBytes = [System.IO.File]::ReadAllBytes($authPathFull)
if (-not (Test-BytesEqual -Left $snapshotBytes -Right $currentBytes)) {
    throw 'Codex 인증 원본이 갱신 직전에 변경되어 덮어쓰지 않았습니다.'
}

[System.IO.File]::Replace($replacementPathFull, $authPathFull, $backupPathFull, $true)
[System.IO.File]::Delete($backupPathFull)
