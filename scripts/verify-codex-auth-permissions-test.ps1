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
Assert-CodexAuthAclRules -AccessRules $safeRules -CurrentUserSid $userSid.Value -TargetName 'fixture'

$unsafeRules = $safeRules + @(
    [System.Security.AccessControl.FileSystemAccessRule]::new(
        $usersSid,
        [System.Security.AccessControl.FileSystemRights]::ReadAndExecute,
        $noInheritance,
        $noPropagation,
        $allow))
$unsafeAclRejected = $false
try {
    Assert-CodexAuthAclRules -AccessRules $unsafeRules -CurrentUserSid $userSid.Value -TargetName 'fixture'
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

$readOnlyRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $userSid,
    [System.Security.AccessControl.FileSystemRights]::Read,
    $noInheritance,
    $noPropagation,
    $allow)
$readOnlyRejected = $false
try {
    Assert-CodexAuthAclRules -AccessRules @($readOnlyRule) -CurrentUserSid $userSid.Value -TargetName 'fixture'
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
