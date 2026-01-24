<#
.SYNOPSIS
    Audits all LOCAL user accounts on a Windows Server to identify those
    with administrative or other high-privilege group memberships.
.DESCRIPTION
    This script queries the local user database to find users who are members of
    key security groups (Administrators, Remote Desktop Users, etc.).
    It generates a report listing these users, their enabled/disabled
    status, and a complete list of all local groups they belong to.

    The final report is exported to "LocalUserPrivilegeReport.csv" in the script's
    execution directory.
.NOTES
    Author:     Windows Server Admin
    Created:    13-Nov-2025
    Requires:   PowerShell 5.1+ and Microsoft.PowerShell.LocalAccounts module.
    Requires:   Run this script as an Administrator.
.EXAMPLE
    .\Get-LocalUserPrivilegeReport.ps1
    (This will run the script on the local server and create 
    "LocalUserPrivilegeReport.csv" in the current folder)
#>

#Requires -RunAsAdministrator

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import the module just in case (it's usually auto-loaded)
Import-Module Microsoft.PowerShell.LocalAccounts

$Report = @()
$ErrorLog = @()

# Define the key administrative groups to check
$PrivilegeGroups = @(
    "Administrators",
    "Remote Desktop Users",
    "Backup Operators",
    "Event Log Readers",
    "Power Users"
)

try {
    Write-Host "Starting local user privilege audit..." -ForegroundColor Cyan

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
        $isPrivileged = $false
        $Privileges = [PSCustomObject]@{}
        
        foreach ($PrivGroup in $PrivilegeGroups) {
            $isMember = $UserGroupNames -contains $PrivGroup
            $Privileges | Add-Member -MemberType NoteProperty -Name "Is$($PrivGroup -replace ' ')" -Value $isMember
            if ($isMember) {
                $isPrivileged = $true
            }
        }

        # If the user has any of these privileges, add them to the report
        # We now add *EVERY* user to the report, regardless of privilege.
        # This 'if' statement is just for a console warning.
        if ($isPrivileged) {
            
            Write-Host "  [!] Found privileged local user: $($User.Name)" -ForegroundColor Yellow
        }
            
        $GroupString = $UserGroupNames -join "; "

            # Create a base object for the report
            $ReportObject = [PSCustomObject]@{
                UserName            = $User.Name
                SID                 = $User.SID.Value
                Enabled             = $User.Enabled
                PasswordLastSet     = $User.PasswordLastSet
                AllAssociatedGroups = $GroupString
            }
            
            # Add all the dynamic "Is<Group>" properties from the $Privileges object
            foreach ($Property in $Privileges.PSObject.Properties) {
                $ReportObject | Add-Member -MemberType NoteProperty -Name $Property.Name -Value $Property.Value
            }
            
            # Now add the completed object to the report
            $Report += $ReportObject
            
    }

    # --- Step 3: Output and Export Report ---
    Write-Progress -Activity "Analyzing Local Users" -Completed

    $ReportPath = ".\LocalUserPrivilegeReport.csv"

    # Export the report. This will create the file even if $Report is empty.
    try {
        $Report | Export-Csv -Path $ReportPath -NoTypeInformation -ErrorAction Stop
        
        # We are now reporting ALL users, so we check for privileged users inside the report.
        $PrivilegedUserCount = ($Report | Where-Object {
            $_.IsAdministrators -or $_.IsRemoteDesktopUsers -or $_.IsBackupOperators -or $_.IsEventLogReaders -or $_.IsPowerUsers
        }).Count

        Write-Host "Analysis complete. Audited $($Report.Count) local users." -ForegroundColor Green
        
        if ($PrivilegedUserCount -gt 0) {
            Write-Host "Found $PrivilegedUserCount users with high privileges." -ForegroundColor Yellow
            
            # Output to console - only show the privileged ones
            Write-Host "--- Privileged Users Found ---" -ForegroundColor Yellow
            $Report | Where-Object { $_.IsAdministrators -or $_.IsRemoteDesktopUsers } | Format-Table UserName, Enabled, IsAdministrators, IsRemoteDesktopUsers

        } else {
            Write-Host "Analysis complete. No high-privilege local users found." -ForegroundColor Green
        }
        
        Write-Host "Full report for ALL local users has been saved to: $ReportPath" -ForegroundColor Cyan

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