[CmdletBinding()]
param(
    [string]$Path,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExpectedRelativePath = @(),
    [switch]$RulesOnly
)

$ErrorActionPreference = 'Stop'
$runningOnWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [System.Runtime.InteropServices.OSPlatform]::Windows)

if ($runningOnWindows -and -not (Get-Command Get-Acl -ErrorAction SilentlyContinue)) {
    $securityModulePath = Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1'
    if (Test-Path -LiteralPath $securityModulePath) {
        Import-Module -Name $securityModulePath -ErrorAction Stop
    }
    else {
        Import-Module -Name Microsoft.PowerShell.Security -ErrorAction Stop
    }
}
if ($runningOnWindows -and -not (Get-Command Get-Acl -ErrorAction SilentlyContinue)) {
    throw 'Microsoft.PowerShell.Security 모듈에서 Get-Acl을 로드하지 못했습니다.'
}

function Get-TrustedBundleItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BundlePath,
        [Parameter(Mandatory = $true)]
        [string[]]$RelativePaths
    )

    $fullBundlePath = [System.IO.Path]::GetFullPath($BundlePath).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar)
    $bundleItem = Get-Item -LiteralPath $fullBundlePath -Force
    if (-not $bundleItem.PSIsContainer) {
        throw "trusted hook bundle이 디렉터리가 아닙니다: $fullBundlePath"
    }

    $items = [System.Collections.Generic.List[object]]::new()
    $items.Add($bundleItem)
    foreach ($relativePath in @($RelativePaths)) {
        if ([string]::IsNullOrWhiteSpace($relativePath) -or [System.IO.Path]::IsPathRooted($relativePath)) {
            throw "trusted hook bundle 상대 경로가 잘못되었습니다: $relativePath"
        }

        $candidatePath = [System.IO.Path]::GetFullPath((Join-Path $fullBundlePath $relativePath))
        $bundlePrefix = $fullBundlePath + [System.IO.Path]::DirectorySeparatorChar
        $pathComparison = if ($runningOnWindows) {
            [System.StringComparison]::OrdinalIgnoreCase
        }
        else {
            [System.StringComparison]::Ordinal
        }
        if (-not $candidatePath.StartsWith($bundlePrefix, $pathComparison)) {
            throw "trusted hook bundle 밖의 경로가 요청되었습니다: $relativePath"
        }
        $parentPath = Split-Path -Parent $candidatePath
        while ($parentPath -ne $fullBundlePath) {
            $items.Add((Get-Item -LiteralPath $parentPath -Force))
            $parentPath = Split-Path -Parent $parentPath
        }
        $items.Add((Get-Item -LiteralPath $candidatePath -Force))
    }

    return $items
}

function Assert-TrustedHookAclRules {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$AccessRules,
        [Parameter(Mandatory = $true)]
        [string]$OwnerSid,
        [Parameter(Mandatory = $true)]
        [string]$CurrentUserSid,
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    $trustedSids = @($CurrentUserSid, 'S-1-5-18', 'S-1-5-32-544')
    if ($trustedSids -notcontains $OwnerSid) {
        throw "$TargetName 소유자가 신뢰된 계정이 아닙니다."
    }
    $writeRights = [int](
        [System.Security.AccessControl.FileSystemRights]::WriteData -bor
        [System.Security.AccessControl.FileSystemRights]::AppendData -bor
        [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
        [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
        [System.Security.AccessControl.FileSystemRights]::Delete -bor
        [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [System.Security.AccessControl.FileSystemRights]::TakeOwnership)

    foreach ($rule in @($AccessRules)) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            continue
        }
        if ($trustedSids -notcontains $rule.IdentityReference.Value -and
            (([int]$rule.FileSystemRights -band $writeRights) -ne 0)) {
            throw "$TargetName ACL에 허용되지 않은 사용자 또는 그룹이 쓰기 권한을 가집니다."
        }
    }
}

function Assert-TrustedHookBundleAcl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BundlePath,
        [Parameter(Mandatory = $true)]
        [string[]]$RelativePaths
    )

    if ($runningOnWindows) {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        if ($null -eq $identity.User) {
            throw '현재 Windows 사용자의 SID를 확인하지 못했습니다.'
        }
    }
    else {
        $statPath = '/usr/bin/stat'
        $idPath = '/usr/bin/id'
        if (-not (Test-Path -LiteralPath $statPath) -or -not (Test-Path -LiteralPath $idPath)) {
            throw 'POSIX 권한 검증에 필요한 stat 또는 id가 없습니다.'
        }
        $currentUid = (& $idPath -u).Trim()
        if ($LASTEXITCODE -ne 0 -or $currentUid -notmatch '^\d+$') {
            throw '현재 POSIX 사용자 UID를 확인하지 못했습니다.'
        }
    }

    foreach ($item in (Get-TrustedBundleItems -BundlePath $BundlePath -RelativePaths $RelativePaths)) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "trusted hook bundle 항목은 재분석 지점일 수 없습니다: $($item.FullName)"
        }

        if ($runningOnWindows) {
            $acl = Get-Acl -LiteralPath $item.FullName
            $accessRules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
            $ownerSid = $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
            Assert-TrustedHookAclRules -AccessRules $accessRules -OwnerSid $ownerSid `
                -CurrentUserSid $identity.User.Value -TargetName "trusted hook bundle: $($item.FullName)"
        }
        else {
            $ownerUid = (& $statPath -c '%u' -- $item.FullName).Trim()
            $mode = (& $statPath -c '%a' -- $item.FullName).Trim()
            if ($LASTEXITCODE -ne 0 -or $ownerUid -notmatch '^\d+$' -or $mode -notmatch '^[0-7]{3,4}$') {
                throw "trusted hook bundle의 POSIX 권한을 확인하지 못했습니다: $($item.FullName)"
            }
            if ($ownerUid -ne $currentUid -and $ownerUid -ne '0') {
                throw "trusted hook bundle 소유자가 신뢰된 계정이 아닙니다: $($item.FullName)"
            }
            $modeDigits = $mode.PadLeft(4, '0')
            if (([int][string]$modeDigits[2] -band 2) -ne 0 -or
                ([int][string]$modeDigits[3] -band 2) -ne 0) {
                throw "trusted hook bundle에 다른 사용자 또는 그룹의 쓰기 권한이 있습니다: $($item.FullName)"
            }
        }
    }
}

if ($RulesOnly) {
    return
}

if ([string]::IsNullOrWhiteSpace($Path)) {
    throw 'trusted hook bundle 경로가 필요합니다.'
}

$relativePaths = @(
    foreach ($value in @($ExpectedRelativePath)) {
        $value -split '\|' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    })
Assert-TrustedHookBundleAcl -BundlePath $Path -RelativePaths $relativePaths
Write-Output 'Trusted hook bundle ACL contract passed'
