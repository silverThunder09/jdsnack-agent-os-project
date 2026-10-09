[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'review-path-safety.ps1')
. (Join-Path $PSScriptRoot 'codex-auth-permissions.ps1')

$fullPath = [System.IO.Path]::GetFullPath($Path)
Assert-NoReparsePointsInPath -Path $fullPath
$homeItem = Get-Item -LiteralPath $fullPath -Force
if (-not $homeItem.PSIsContainer) {
    throw 'CODEX_HOME이 디렉터리가 아닙니다.'
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
if ($null -eq $identity.User) {
    throw '현재 Windows 사용자의 SID를 확인하지 못했습니다.'
}

$currentUserSid = $identity.User.Value

function Assert-RestrictedAuthAcl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    Assert-NoReparsePointsInPath -Path $TargetPath
    $acl = Get-Acl -LiteralPath $TargetPath
    $rules = @($acl.GetAccessRules(
        $true,
        $true,
        [System.Security.Principal.SecurityIdentifier]))
    $checkArguments = @{
        AccessRules = $rules
        CurrentUserSid = $currentUserSid
        TargetName = $TargetName
    }
    if ($TargetName -eq 'CODEX_HOME') {
        $checkArguments.AllowReadOnlyPrincipals = $true
    }
    Assert-CodexAuthAclRules @checkArguments
}

Assert-RestrictedAuthAcl -TargetPath $fullPath -TargetName 'CODEX_HOME'

$authPath = Join-Path $fullPath 'auth.json'
$authItem = Get-Item -LiteralPath $authPath -Force -ErrorAction SilentlyContinue
if ($null -ne $authItem) {
    if ($authItem.PSIsContainer) {
        throw 'Codex auth.json 경로가 일반 파일이 아닙니다.'
    }
    Assert-RestrictedAuthAcl -TargetPath $authPath -TargetName 'Codex auth.json'
}
