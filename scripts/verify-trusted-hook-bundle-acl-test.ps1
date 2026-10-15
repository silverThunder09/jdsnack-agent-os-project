[CmdletBinding()]
param([string]$Workspace = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$verifier = Join-Path $Workspace 'scripts/trusted-hooks/verify-trusted-hook-bundle-acl.ps1'
. $verifier -RulesOnly

function Assert-Rejected([scriptblock]$Action, [string]$Message) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw $Message }
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-acl-' + [guid]::NewGuid().ToString('N'))
$bundle = Join-Path $root 'hooks'
New-Item -ItemType Directory -Path (Join-Path $bundle 'scripts') -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $bundle 'scripts/check.py') -Force | Out-Null
try {
    $items = @(Get-TrustedBundleItems -BundlePath $bundle -RelativePaths @('scripts/check.py'))
    if ($items.FullName -notcontains (Get-Item -LiteralPath $root).FullName) { throw 'ACL validation omitted the bundle parent.' }
    Assert-Rejected { Get-TrustedBundleItems -BundlePath $bundle -RelativePaths @('../outside') } 'Path traversal was accepted.'

    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        $user = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-21-100-200-300-400')
        $users = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
        $system = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
        $admins = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
        $full = [System.Security.AccessControl.FileSystemRights]::FullControl
        $allow = [System.Security.AccessControl.AccessControlType]::Allow
        $none = [System.Security.AccessControl.InheritanceFlags]::None
        $propagation = [System.Security.AccessControl.PropagationFlags]::None
        $safe = @(
            [System.Security.AccessControl.FileSystemAccessRule]::new($user, $full, $none, $propagation, $allow),
            [System.Security.AccessControl.FileSystemAccessRule]::new($system, $full, $none, $propagation, $allow),
            [System.Security.AccessControl.FileSystemAccessRule]::new($admins, $full, $none, $propagation, $allow))
        Assert-TrustedHookAclRules -AccessRules $safe -OwnerSid $user.Value -CurrentUserSid $user.Value -TargetName 'safe fixture'
        $unsafe = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $users, [System.Security.AccessControl.FileSystemRights]::Modify, $none, $propagation, $allow)
        Assert-Rejected {
            Assert-TrustedHookAclRules -AccessRules ($safe + $unsafe) -OwnerSid $user.Value -CurrentUserSid $user.Value -TargetName 'unsafe fixture'
        } 'Writable Users ACE was accepted.'
        $inherited = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $users, $full, [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
            [System.Security.AccessControl.PropagationFlags]::InheritOnly, $allow)
        Assert-TrustedHookAclRules -AccessRules ($safe + $inherited) -OwnerSid $user.Value -CurrentUserSid $user.Value -TargetName 'ancestor fixture' -AncestorDirectory
    }
    else {
        & /usr/bin/chmod 777 -- $root
        Assert-Rejected { Assert-TrustedHookBundleAcl -BundlePath $bundle -RelativePaths @('scripts/check.py') } 'Writable parent directory was accepted.'
        & /usr/bin/chmod 700 -- $root
        & /usr/bin/chmod 666 -- (Join-Path $bundle 'scripts/check.py')
        Assert-Rejected { Assert-TrustedHookBundleAcl -BundlePath $bundle -RelativePaths @('scripts/check.py') } 'Writable bundle file was accepted.'
    }
    Write-Output 'Trusted hook ACL contract passed.'
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
