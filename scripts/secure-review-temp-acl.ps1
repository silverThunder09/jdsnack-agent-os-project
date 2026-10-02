[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;

public static class ReviewRestrictedTokenSids
{
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(IntPtr token, int informationClass, IntPtr information, int length, out int returnedLength);

    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);

    public static string[] GetRestrictedSids()
    {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), 0x0008, out token))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        try
        {
            int requiredLength;
            GetTokenInformation(token, 11, IntPtr.Zero, 0, out requiredLength);
            if (requiredLength <= 0)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            IntPtr buffer = Marshal.AllocHGlobal(requiredLength);
            try
            {
                if (!GetTokenInformation(token, 11, buffer, requiredLength, out requiredLength))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                int count = Marshal.ReadInt32(buffer);
                int groupsOffset = IntPtr.Size == 8 ? 8 : 4;
                int entrySize = IntPtr.Size == 8 ? 16 : 8;
                string[] result = new string[count];
                for (int index = 0; index < count; index++)
                {
                    IntPtr entry = IntPtr.Add(buffer, groupsOffset + index * entrySize);
                    result[index] = new SecurityIdentifier(Marshal.ReadIntPtr(entry)).Value;
                }
                return result;
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }
        finally
        {
            CloseHandle(token);
        }
    }
}

public static class ReviewProtectedAclWriter
{
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    private static extern uint SetNamedSecurityInfo(
        string objectName,
        int objectType,
        uint securityInformation,
        IntPtr owner,
        IntPtr group,
        IntPtr discretionaryAcl,
        IntPtr systemAcl);

    public static void SetProtectedDacl(string path, string[] sids, bool isDirectory)
    {
        RawAcl acl = new RawAcl(GenericAcl.AclRevision, sids.Length);
        AceFlags flags = isDirectory ? AceFlags.ObjectInherit | AceFlags.ContainerInherit : AceFlags.None;
        int fullControl = (int)FileSystemRights.FullControl;
        foreach (string sid in sids)
        {
            acl.InsertAce(acl.Count, new CommonAce(
                flags,
                AceQualifier.AccessAllowed,
                fullControl,
                new SecurityIdentifier(sid),
                false,
                null));
        }

        byte[] binaryAcl = new byte[acl.BinaryLength];
        acl.GetBinaryForm(binaryAcl, 0);
        IntPtr aclBuffer = Marshal.AllocHGlobal(binaryAcl.Length);
        try
        {
            Marshal.Copy(binaryAcl, 0, aclBuffer, binaryAcl.Length);
            uint result = SetNamedSecurityInfo(path, 1, 0x00000004 | 0x80000000,
                IntPtr.Zero, IntPtr.Zero, aclBuffer, IntPtr.Zero);
            if (result != 0)
            {
                throw new Win32Exception((int)result);
            }
        }
        finally
        {
            Marshal.FreeHGlobal(aclBuffer);
        }
    }
}
'@

$fullPath = [System.IO.Path]::GetFullPath($Path)
$item = Get-Item -LiteralPath $fullPath
$parentPath = [System.IO.Directory]::GetParent($fullPath).FullName
$parentAcl = Get-Acl -LiteralPath $parentPath
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
if ($null -eq $identity.User) {
    throw '현재 Windows 사용자의 SID를 확인하지 못했습니다.'
}

$restrictedSids = @([ReviewRestrictedTokenSids]::GetRestrictedSids())
$restrictedAccessSids = @()
$writeMask = [int]([System.Security.AccessControl.FileSystemRights]::WriteData -bor
    [System.Security.AccessControl.FileSystemRights]::AppendData -bor
    [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
    [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
    [System.Security.AccessControl.FileSystemRights]::Delete -bor
    [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles)

foreach ($rule in $parentAcl.Access) {
    if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
        (([int]$rule.FileSystemRights -band $writeMask) -eq 0)) {
        continue
    }

    try {
        if ($rule.IdentityReference -is [System.Security.Principal.SecurityIdentifier]) {
            $sid = $rule.IdentityReference.Value
        }
        else {
            $sid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
        }
    }
    catch {
        continue
    }

    if ($restrictedSids -contains $sid) {
        $restrictedAccessSids += $sid
    }
}

$restrictedAccessSids = @($restrictedAccessSids | Sort-Object -Unique)
if ($restrictedSids.Count -gt 0 -and $restrictedAccessSids.Count -eq 0) {
    throw '부모 임시 경로에서 현재 제한 토큰의 쓰기 권한 SID를 확인하지 못했습니다.'
}

$allowedSids = @(
    $identity.User.Value,
    'S-1-5-18',
    'S-1-5-32-544'
) + $restrictedAccessSids | Sort-Object -Unique
$isDirectory = [bool]$item.PSIsContainer

if (-not $VerifyOnly) {
    [ReviewProtectedAclWriter]::SetProtectedDacl($fullPath, [string[]]$allowedSids, $isDirectory)
}

$actualAcl = Get-Acl -LiteralPath $fullPath
if (-not $actualAcl.AreAccessRulesProtected) {
    throw '임시 경로 ACL의 상속이 차단되지 않았습니다.'
}

$actualRules = @($actualAcl.GetAccessRules(
    $true,
    $true,
    [System.Security.Principal.SecurityIdentifier]
))
if ($actualRules.Count -ne $allowedSids.Count) {
    throw '임시 경로 ACL에 허용 목록 외의 권한이 있거나 필수 권한이 누락됐습니다.'
}

$expectedInheritance = [System.Security.AccessControl.InheritanceFlags]::None
if ($isDirectory) {
    $expectedInheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
}

foreach ($rule in $actualRules) {
    if (($allowedSids -notcontains $rule.IdentityReference.Value) -or
        $rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
        $rule.FileSystemRights -ne [System.Security.AccessControl.FileSystemRights]::FullControl -or
        $rule.InheritanceFlags -ne $expectedInheritance -or
        $rule.PropagationFlags -ne [System.Security.AccessControl.PropagationFlags]::None) {
        throw '임시 경로 ACL이 현재 제한 실행 환경의 허용 목록과 일치하지 않습니다.'
    }
}
