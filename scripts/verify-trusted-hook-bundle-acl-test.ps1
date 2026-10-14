[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$runningOnWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [System.Runtime.InteropServices.OSPlatform]::Windows)
$securityModulePath = Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1'
if ($runningOnWindows -and -not (Get-Command Get-Acl -ErrorAction SilentlyContinue)) {
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
    if ($runningOnWindows) {
    & $secureAclPath -Path $bundlePath | Out-Null

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

    $createChildRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $usersSid,
        [System.Security.AccessControl.FileSystemRights]::CreateDirectories,
        $noInheritance,
        $noPropagation,
        $allow)
    Assert-TrustedHookAclRules -AccessRules ($safeRules + $createChildRule) -OwnerSid $userSid.Value `
        -CurrentUserSid $userSid.Value -TargetName 'ancestor fixture' -AncestorDirectory
    $inheritOnlyRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $usersSid,
        $fullControl,
        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
        [System.Security.AccessControl.PropagationFlags]::InheritOnly,
        $allow)
    Assert-TrustedHookAclRules -AccessRules ($safeRules + $inheritOnlyRule) -OwnerSid $userSid.Value `
        -CurrentUserSid $userSid.Value -TargetName 'ancestor fixture' -AncestorDirectory

    $bundleItems = @(Get-TrustedBundleItems -BundlePath $bundlePath -RelativePaths $expectedPaths)
    if ($bundleItems.FullName -notcontains (Get-Item -LiteralPath $workspaceRoot).FullName) {
        throw 'trusted hook bundle 상위 디렉터리가 ACL 검사 대상에 포함되지 않았습니다.'
    }
    $actualUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $actualSafeRules = @(
        [System.Security.AccessControl.FileSystemAccessRule]::new($actualUserSid, $fullControl, $noInheritance, $noPropagation, $allow),
        [System.Security.AccessControl.FileSystemAccessRule]::new($systemSid, $fullControl, $noInheritance, $noPropagation, $allow),
        [System.Security.AccessControl.FileSystemAccessRule]::new($administratorsSid, $fullControl, $noInheritance, $noPropagation, $allow))
    $safeAcl = [pscustomobject]@{ OwnerSid = $actualUserSid; Rules = $actualSafeRules }
    $safeAcl | Add-Member -MemberType ScriptMethod -Name GetOwner -Value { param($sidType) $this.OwnerSid }
    $safeAcl | Add-Member -MemberType ScriptMethod -Name GetAccessRules -Value {
        param($explicit, $inherited, $sidType) $this.Rules
    }
    $unsafeParentAcl = [pscustomobject]@{ OwnerSid = $actualUserSid; Rules = @($actualSafeRules + $unsafeRule) }
    $unsafeParentAcl | Add-Member -MemberType ScriptMethod -Name GetOwner -Value { param($sidType) $this.OwnerSid }
    $unsafeParentAcl | Add-Member -MemberType ScriptMethod -Name GetAccessRules -Value {
        param($explicit, $inherited, $sidType) $this.Rules
    }
    $script:aclFixtureUnsafeParent = $false
    function Get-Acl {
        param([string]$LiteralPath)
        if ($script:aclFixtureUnsafeParent -and $LiteralPath -eq $workspaceRoot) {
            return $unsafeParentAcl
        }
        return $safeAcl
    }
    try {
        Assert-TrustedHookBundleAcl -BundlePath $bundlePath -RelativePaths $expectedPaths
        $script:aclFixtureUnsafeParent = $true
        $rejected = $false
        try {
            Assert-TrustedHookBundleAcl -BundlePath $bundlePath -RelativePaths $expectedPaths
        }
        catch {
            $rejected = $_.Exception.Message -match '쓰기 권한'
            if (-not $rejected) { throw }
        }
        if (-not $rejected) {
            throw 'trusted hook bundle의 쓰기 가능한 상위 디렉터리를 거부하지 않았습니다.'
        }
    }
    finally {
        Remove-Item Function:\Get-Acl
    }

    foreach ($genericRight in @(0x10000000, 0x40000000)) {
        # FileSystemAccessRule rejects raw generic bits at construction time,
        # so model the ACE returned by GetAccessRules with those bits intact.
        $genericRule = [pscustomobject]@{
            AccessControlType = $allow
            IdentityReference = $usersSid
            FileSystemRights = $genericRight
        }
        $rejected = $false
        try {
            Assert-TrustedHookAclRules -AccessRules ($safeRules + $genericRule) -OwnerSid $userSid.Value `
                -CurrentUserSid $userSid.Value -TargetName 'fixture'
        }
        catch {
            $rejected = $_.Exception.Message -match '쓰기 권한'
            if (-not $rejected) {
                throw
            }
        }
        if (-not $rejected) {
            throw ('trusted hook bundle의 generic 쓰기 권한을 거부하지 않았습니다: 0x{0:X8}' -f $genericRight)
        }
    }

    Write-Output 'Trusted hook bundle writable ACL contract passed'
    }
    else {
        & $verifierPath -Path $bundlePath -ExpectedRelativePath $expectedPaths | Out-Null
        & /usr/bin/chmod 777 -- $workspaceRoot
        $rejected = $false
        try {
            & $verifierPath -Path $bundlePath -ExpectedRelativePath $expectedPaths | Out-Null
        }
        catch {
            $rejected = $_.Exception.Message -match '쓰기 권한'
            if (-not $rejected) { throw }
        }
        if (-not $rejected) {
            throw 'trusted hook bundle의 POSIX 상위 디렉터리 쓰기 권한을 거부하지 않았습니다.'
        }
        & /usr/bin/chmod 700 -- $workspaceRoot
        $unsafePath = Join-Path $bundlePath 'pre-push'
        & /usr/bin/chmod 666 -- $unsafePath
        if ($LASTEXITCODE -ne 0) {
            throw 'POSIX 권한 fixture를 설정하지 못했습니다.'
        }
        $rejected = $false
        try {
            & $verifierPath -Path $bundlePath -ExpectedRelativePath $expectedPaths | Out-Null
        }
        catch {
            $rejected = $_.Exception.Message -match '쓰기 권한'
            if (-not $rejected) {
                throw
            }
        }
        if (-not $rejected) {
            throw 'trusted hook bundle의 POSIX group/world 쓰기 권한을 거부하지 않았습니다.'
        }
        & /usr/bin/chmod 600 -- $unsafePath
        Write-Output 'Trusted hook bundle POSIX permissions contract passed'
    }
}
finally {
    if (Test-Path -LiteralPath $workspaceRoot) {
        Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
    }
}
