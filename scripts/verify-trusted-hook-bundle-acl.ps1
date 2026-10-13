[CmdletBinding()]
param(
    [string]$Path,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExpectedRelativePath = @(),
    [switch]$RulesOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command Get-Acl -ErrorAction SilentlyContinue)) {
    $securityModulePath = Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1'
    if (Test-Path -LiteralPath $securityModulePath) {
        Import-Module -Name $securityModulePath -ErrorAction Stop
    }
    else {
        Import-Module -Name Microsoft.PowerShell.Security -ErrorAction Stop
    }
}
if (-not (Get-Command Get-Acl -ErrorAction SilentlyContinue)) {
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
        if (-not $candidatePath.StartsWith($bundlePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "trusted hook bundle 밖의 경로가 요청되었습니다: $relativePath"
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

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if ($null -eq $identity.User) {
        throw '현재 Windows 사용자의 SID를 확인하지 못했습니다.'
    }

    foreach ($item in (Get-TrustedBundleItems -BundlePath $BundlePath -RelativePaths $RelativePaths)) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "trusted hook bundle 항목은 재분석 지점일 수 없습니다: $($item.FullName)"
        }

        $acl = Get-Acl -LiteralPath $item.FullName
        $accessRules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
        $ownerSid = $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
        Assert-TrustedHookAclRules -AccessRules $accessRules -OwnerSid $ownerSid `
            -CurrentUserSid $identity.User.Value -TargetName "trusted hook bundle: $($item.FullName)"
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
