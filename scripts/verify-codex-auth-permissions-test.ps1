[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
. (Join-Path $Workspace 'scripts/codex-auth-permissions.ps1')

$userSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-21-100-200-300-400')
$usersSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
$systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$administratorsSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
$allow = [System.Security.AccessControl.AccessControlType]::Allow
$noInheritance = [System.Security.AccessControl.InheritanceFlags]::None
$noPropagation = [System.Security.AccessControl.PropagationFlags]::None

$safeRules = @(
    [System.Security.AccessControl.FileSystemAccessRule]::new($userSid, $fullControl, $noInheritance, $noPropagation, $allow),
    [System.Security.AccessControl.FileSystemAccessRule]::new($systemSid, $fullControl, $noInheritance, $noPropagation, $allow),
    [System.Security.AccessControl.FileSystemAccessRule]::new($administratorsSid, $fullControl, $noInheritance, $noPropagation, $allow))
Assert-CodexAuthAclRules -AccessRules $safeRules -OwnerSid $userSid.Value -CurrentUserSid $userSid.Value -TargetName 'fixture'

$ownerRejected = $false
try {
    Assert-CodexAuthAclRules -AccessRules $safeRules -OwnerSid $usersSid.Value -CurrentUserSid $userSid.Value -TargetName 'fixture'
}
catch {
    $ownerRejected = $_.Exception.Message -match '소유자가 현재 사용자 또는 신뢰된 시스템 계정이 아닙니다'
    if (-not $ownerRejected) {
        throw
    }
}
if (-not $ownerRejected) {
    throw '다른 사용자가 소유한 인증 경로를 거부하지 않았습니다.'
}

$unsafeRules = $safeRules + @(
    [System.Security.AccessControl.FileSystemAccessRule]::new(
        $usersSid,
        [System.Security.AccessControl.FileSystemRights]::ReadAndExecute,
        $noInheritance,
        $noPropagation,
        $allow))
$unsafeAclRejected = $false
try {
    Assert-CodexAuthAclRules -AccessRules $unsafeRules -OwnerSid $userSid.Value -CurrentUserSid $userSid.Value -TargetName 'fixture'
}
catch {
    $unsafeAclRejected = $_.Exception.Message -match '허용되지 않은 사용자 또는 그룹'
    if (-not $unsafeAclRejected) {
        throw
    }
}
if (-not $unsafeAclRejected) {
    throw '다른 사용자 읽기 권한이 있는 ACL을 거부하지 않았습니다.'
}

Assert-CodexAuthAclRules -AccessRules $unsafeRules -OwnerSid $userSid.Value -CurrentUserSid $userSid.Value -TargetName 'CODEX_HOME' -AllowReadOnlyPrincipals

$writeAccessRules = $safeRules + @(
    [System.Security.AccessControl.FileSystemAccessRule]::new(
        $usersSid,
        [System.Security.AccessControl.FileSystemRights]::Modify,
        $noInheritance,
        $noPropagation,
        $allow))
$writeAclRejected = $false
try {
    Assert-CodexAuthAclRules -AccessRules $writeAccessRules -OwnerSid $userSid.Value -CurrentUserSid $userSid.Value -TargetName 'CODEX_HOME' -AllowReadOnlyPrincipals
}
catch {
    $writeAclRejected = $_.Exception.Message -match '허용되지 않은 사용자 또는 그룹'
    if (-not $writeAclRejected) {
        throw
    }
}
if (-not $writeAclRejected) {
    throw 'CODEX_HOME에 다른 사용자 쓰기 권한이 있어도 검증이 통과했습니다.'
}

$readOnlyRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $userSid,
    [System.Security.AccessControl.FileSystemRights]::Read,
    $noInheritance,
    $noPropagation,
    $allow)
$readOnlyRejected = $false
try {
    Assert-CodexAuthAclRules -AccessRules @($readOnlyRule) -OwnerSid $userSid.Value -CurrentUserSid $userSid.Value -TargetName 'fixture'
}
catch {
    $readOnlyRejected = $_.Exception.Message -match '읽기·쓰기 권한이 충분하지 않습니다'
    if (-not $readOnlyRejected) {
        throw
    }
}
if (-not $readOnlyRejected) {
    throw '현재 사용자의 읽기 전용 ACL을 거부하지 않았습니다.'
}

Write-Output 'Codex auth permission contract passed'
