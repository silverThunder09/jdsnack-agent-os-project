function Assert-CodexAuthAclRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$AccessRules,
        [Parameter(Mandatory = $true)]
        [string]$CurrentUserSid,
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    $allowedSids = @($CurrentUserSid, 'S-1-5-18', 'S-1-5-32-544')
    $requiredRights = [int](
        [System.Security.AccessControl.FileSystemRights]::ReadData -bor
        [System.Security.AccessControl.FileSystemRights]::WriteData -bor
        [System.Security.AccessControl.FileSystemRights]::AppendData -bor
        [System.Security.AccessControl.FileSystemRights]::ReadAttributes -bor
        [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
        [System.Security.AccessControl.FileSystemRights]::ReadPermissions -bor
        [System.Security.AccessControl.FileSystemRights]::Synchronize)
    $userGrantedRights = 0

    foreach ($rule in $AccessRules) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
            (($rule.PropagationFlags -band [System.Security.AccessControl.PropagationFlags]::InheritOnly) -ne 0)) {
            continue
        }

        $sid = $rule.IdentityReference.Value
        if ($allowedSids -notcontains $sid) {
            throw "$TargetName ACL에 허용되지 않은 사용자 또는 그룹이 있습니다."
        }

        if ($sid -eq $CurrentUserSid) {
            $userGrantedRights = $userGrantedRights -bor [int]$rule.FileSystemRights
        }
    }

    if (($userGrantedRights -band $requiredRights) -ne $requiredRights) {
        throw "$TargetName ACL에 현재 사용자 읽기·쓰기 권한이 충분하지 않습니다."
    }
}
