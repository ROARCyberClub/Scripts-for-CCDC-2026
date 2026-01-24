<#
.SYNOPSIS
    Audits all LOCAL user accounts on a Windows machine to find users
    with Remote Desktop (RDP) privileges.
.DESCRIPTION
    This script audits all local users and checks if they are members of the
    "Remote Desktop Users" group or the "Administrators" group (who also
    have RDP rights). It lists all users and their groups in a CSV report.
.NOTES
    Author:     Windows Server Admin
    Created:    13-Nov-2025
    Requires:   PowerShell 5.1+ and Microsoft.PowerShell.LocalAccounts module.
    Requires:   Run this script as an Administrator.
.EXAMPLE
    .\Audit-LocalRDPUsers.ps1
    (This will run the script on the local server and create 
    "LocalRDP_Audit_Report.csv" in the current folder)
#>

#Requires -RunAsAdministrator

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import the module just in case (it's usually auto-loaded)
Import-Module Microsoft.PowerShell.LocalAccounts

$Report = @()
$ErrorLog = @()
$ReportPath = ".\LocalRDP_Audit_Report.csv"

# Define the key groups that grant RDP access
$RDPGroups = @(
    "Administrators",
    "Remote Desktop Users"
)

try {
    Write-Host "Starting local RDP user audit..." -ForegroundColor Cyan

    # --- Step 1: Get all local users ---
    Write-Host "Fetching all local user accounts..."
    try {
        $AllUsers = Get-LocalUser -ErrorAction Stop
        Write-Host "Found $($AllUsers.Count) total local users. Analyzing..."
    } catch {
        throw "Could not retrieve local users. Make sure you are running this as Administrator. Error: $_.Exception.Message"
    }

    # --- Step 2: Analyze each user for privileges ---
    $i = 0
    foreach ($User in $AllUsers) {
        $i++
        Write-Progress -Activity "Analyzing Local Users" -Status "Processing $($User.Name)" -PercentComplete (($i / $AllUsers.Count) * 100)

        $UserGroupNames = @()
        
        try {
            # Get all groups this specific user is a member of
            $UserGroups = $User | Get-LocalGroup -ErrorAction SilentlyContinue
            if ($UserGroups) {
                $UserGroupNames = $UserGroups.Name
            }
        } catch {
            $ErrorLog += "Could not get groups for user '$($User.Name)'. Error: $_.Exception.Message"
            continue # Skip to the next user
        }

        # Check for membership in the key groups
        $isAdmin   = $UserGroupNames -contains "Administrators"
        $isRDPUser = $UserGroupNames -contains "Remote Desktop Users"
        $hasRDPAccess = $isAdmin -or $isRDPUser

        # Show a console warning for privileged users
        if ($hasRDPAccess) {
            Write-Host "  [!] User '$($User.Name)' has RDP access." -ForegroundColor Yellow
        }
            
        # Format groups for CSV
        $GroupString = $UserGroupNames -join "; "

        # Create the custom object for the report
        $Report += [PSCustomObject]@{
            UserName            = $User.Name
            Enabled             = $User.Enabled
            HasRDP_Access       = $hasRDPAccess
            IsAdmin             = $isAdmin
            IsRemoteDesktopUser = $isRDPUser
            AllAssociatedGroups = $GroupString
            SID                 = $User.SID.Value
            PasswordLastSet     = $User.PasswordLastSet
        }
    }

    # --- Step 3: Output and Export Report ---
    Write-Progress -Activity "Analyzing Local Users" -Completed

    try {
        $Report | Export-Csv -Path $ReportPath -NoTypeInformation -ErrorAction Stop
        
        $PrivilegedUserCount = ($Report | Where-Object { $_.HasRDP_Access -eq $true }).Count

        Write-Host "-----------------------------------------------------" -ForegroundColor Green
        Write-Host "Analysis complete. Audited $($Report.Count) local users." -ForegroundColor Green
        
        if ($PrivilegedUserCount -gt 0) {
            Write-Host "Found $PrivilegedUserCount users with RDP access." -ForegroundColor Yellow
        } else {
            Write-Host "No local users found with RDP access." -ForegroundColor Green
        }
        
        Write-Host "Full report for ALL local users has been saved to:" -ForegroundColor Cyan
        Write-Host $ReportPath -ForegroundColor Cyan
        Write-Host "-----------------------------------------------------"

    } catch {
        Write-Error "Could not write report to '$ReportPath'. Error: $_.Exception.Message"
        $ErrorLog += "Could not write report to '$ReportPath'. Error: $_.Exception.Message"
    }

    if ($ErrorLog.Count -gt 0) {
        Write-Warning "Completed with warnings:"
        $ErrorLog | ForEach-Object { Write-Warning $_ }
    }

} catch {
    Write-Error "An unrecoverable error occurred: $_.Exception.Message"
}