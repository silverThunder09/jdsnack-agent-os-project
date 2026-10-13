[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$securityModulePath = Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1'
if (-not (Get-Command Get-Acl -ErrorAction SilentlyContinue)) {
    if (Test-Path -LiteralPath $securityModulePath) {
        Import-Module -Name $securityModulePath -ErrorAction Stop
    }
    else {
        Import-Module -Name Microsoft.PowerShell.Security -ErrorAction Stop
    }
}

$verifierPath = Join-Path $Workspace 'scripts/verify-trusted-hook-bundle-acl.ps1'
$secureAclPath = Join-Path $Workspace 'scripts/secure-review-temp-acl.ps1'
$workspaceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-trusted-bundle-acl-' + [guid]::NewGuid().ToString('N'))
$bundlePath = Join-Path $workspaceRoot 'jdsnack-hooks'
$expectedPaths = @(
    'pre-commit',
    'pre-push',
    'bundle-manifest',
    'source-sha',
    'trusted-source-sha',
    'trusted-source-ref',
    'scripts/verify-trusted-hook-bundle-acl.ps1')

New-Item -ItemType Directory -Path (Join-Path $bundlePath 'scripts') -Force | Out-Null
foreach ($relativePath in $expectedPaths) {
    $targetPath = Join-Path $bundlePath $relativePath
    if ($relativePath -like '*/*') {
        New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
    }
    New-Item -ItemType File -Path $targetPath -Force | Out-Null
}

try {
    & $secureAclPath -Path $bundlePath | Out-Null
    & $verifierPath -Path $bundlePath -ExpectedRelativePath $expectedPaths | Out-Null

    . $verifierPath -RulesOnly
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
    Assert-TrustedHookAclRules -AccessRules $safeRules -OwnerSid $userSid.Value `
        -CurrentUserSid $userSid.Value -TargetName 'fixture'
    $unsafeRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $usersSid,
        [System.Security.AccessControl.FileSystemRights]::Modify,
        $noInheritance,
        $noPropagation,
        $allow)

    $rejected = $false
    try {
        Assert-TrustedHookAclRules -AccessRules ($safeRules + $unsafeRule) -OwnerSid $userSid.Value `
            -CurrentUserSid $userSid.Value -TargetName 'fixture'
    }
    catch {
        $rejected = $_.Exception.Message -match '쓰기 권한'
        if (-not $rejected) {
            throw
        }
    }
    if (-not $rejected) {
        throw 'trusted hook bundle의 다른 사용자 쓰기 권한을 거부하지 않았습니다.'
    }

    Write-Output 'Trusted hook bundle writable ACL contract passed'
}
finally {
    if (Test-Path -LiteralPath $workspaceRoot) {
        Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
    }
}
