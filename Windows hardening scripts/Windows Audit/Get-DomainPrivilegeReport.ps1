<#
.SYNOPSIS
    Audits all Active Directory domain users to identify those with administrative
    privileges (Domain Admin, Enterprise Admin, Administrators) or Remote Desktop
    access (Remote Desktop Users).
.DESCRIPTION
    This script queries Active Directory to find users who are members of key
    security groups. It generates a report listing these users, their enabled/disabled
    status, their specific privileges, and a complete list of all groups they
    belong to.

    The final report is exported to "DomainPrivilegeReport.csv" in the script's
    execution directory.
.NOTES
    Author:     Windows Server Domain Admin
    Created:    13-Nov-2025
    Requires:   ActiveDirectory PowerShell Module (part of RSAT).
.EXAMPLE
    .\Get-DomainPrivilegeReport.ps1
    (This will run the script and create "DomainPrivilegeReport.csv" in the current folder)
.How to run
	Powershell terminal as an Administrators
	run: .\Get-DomainPrivilegeReport.ps1
#>

#Requires -Module ActiveDirectory

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import the module just in case
Import-Module ActiveDirectory

$Report = @()
$ErrorLog = @()

# Define the key administrative groups to check
$PrivilegeGroups = @(
    "Domain Admins",
    "Enterprise Admins",
    "Administrators",         # Built-in Administrators group
    "Remote Desktop Users"    # Built-in RDP Users group
)

$GroupDNs = @{}

try {
    Write-Host "Starting domain privilege audit..." -ForegroundColor Cyan

    # --- Step 1: Get the Distinguished Names (DNs) of the privilege groups ---
    Write-Host "Fetching key security groups..."
    foreach ($GroupName in $PrivilegeGroups) {
        try {
            $Group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
            $GroupDNs[$GroupName] = $Group.DistinguishedName
            Write-Host "  [SUCCESS] Found group: $GroupName" -ForegroundColor Green
        } catch {
            Write-Warning "Could not find group '$GroupName'. This group will be skipped."
            $ErrorLog += "Could not find group '$GroupName': $_.Exception.Message"
        }
    }

    # Stop if no valid groups were found
    if ($GroupDNs.Keys.Count -eq 0) {
        throw "No valid privilege groups could be found. Aborting script."
    }

    # --- Step 2: Fetch all domain users ---
    Write-Host "Fetching all domain users. This may take a while in large domains..."
    $AllUsers = Get-ADUser -Filter * -Properties MemberOf, Enabled -ErrorAction Stop
    Write-Host "Found $($AllUsers.Count) total users. Analyzing..."

    # --- Step 3: Analyze each user for privileges ---
    $i = 0
    foreach ($User in $AllUsers) {
        $i++
        Write-Progress -Activity "Analyzing Users" -Status "Processing $($User.SamAccountName)" -PercentComplete (($i / $AllUsers.Count) * 100)

        # Get the user's group memberships
        $UserGroupDNs = $User.MemberOf
        
        # Check for membership in the key groups
        $isDomainAdmin     = $GroupDNs.ContainsKey("Domain Admins") -and ($UserGroupDNs -contains $GroupDNs["Domain Admins"])
        $isEnterpriseAdmin = $GroupDNs.ContainsKey("Enterprise Admins") -and ($UserGroupDNs -contains $GroupDNs["Enterprise Admins"])
        $isBuiltinAdmin    = $GroupDNs.ContainsKey("Administrators") -and ($UserGroupDNs -contains $GroupDNs["Administrators"])
        $isRDPUser         = $GroupDNs.ContainsKey("Remote Desktop Users") -and ($UserGroupDNs -contains $GroupDNs["Remote Desktop Users"])

        # If the user has any of these privileges, add them to the report
        if ($isDomainAdmin -or $isEnterpriseAdmin -or $isBuiltinAdmin -or $isRDPUser) {
            
            Write-Host "  [!] Found privileged user: $($User.SamAccountName)" -ForegroundColor Yellow

            # Get all group names.
            # This method parses the CN from the DN, which is much faster than
            # running Get-ADGroup for every single group.
            $AllGroupNames = $UserGroupDNs | ForEach-Object {
                ($_ -split ',')[0].Replace('CN=','')
            } | Sort-Object
            
            $GroupString = $AllGroupNames -join "; "

            # Create a custom object for the report
            $Report += [PSCustomObject]@{
                UserName            = $User.SamAccountName
                DistinguishedName   = $User.DistinguishedName
                Enabled             = $User.Enabled
                IsDomainAdmin       = $isDomainAdmin
                IsEnterpriseAdmin   = $isEnterpriseAdmin
                IsBuiltinAdmin      = $isBuiltinAdmin
                IsRemoteDesktopUser = $isRDPUser
                AllAssociatedGroups = $GroupString
            }
        }
    }

    # --- Step 4: Output and Export Report ---
    Write-Progress -Activity "Analyzing Users" -Completed

    if ($Report.Count -gt 0) {
        $ReportPath = ".\DomainPrivilegeReport.csv"
        Write-Host "Analysis complete. Found $($Report.Count) privileged users." -ForegroundColor Green
        
        # Output to console
        $Report | Format-Table UserName, Enabled, IsDomainAdmin, IsEnterpriseAdmin, IsRDPUser

        # Export to CSV
        $Report | Export-Csv -Path $ReportPath -NoTypeInformation
        Write-Host "Full report exported to: $ReportPath" -ForegroundColor Green

    } else {
        Write-Host "Analysis complete. No users found with the specified privileges." -ForegroundColor Green
    }

    if ($ErrorLog.Count -gt 0) {
        Write-Warning "Completed with warnings:"
        $ErrorLog | ForEach-Object { Write-Warning $_ }
    }

} catch {
    Write-Error "An unrecoverable error occurred: $_.Exception.Message"
    if ($_.Exception.Message -like "*'Get-ADGroup'*") {
        Write-Warning "Please ensure the ActiveDirectory module is installed (RSAT) and you are running this script with domain privileges."
    }
}