# PNW Windows DHCP Hardening Script 2026 
# 1. Check if DHCP Role is installed
if ((Get-WindowsFeature -Name DHCP).Installed) {
    Write-Host "DHCP Role found." 
} else {
    Write-Host "DHCP Role NOT found. Exiting."
    Exit
}

# 2. Enable Audit Logging 
try {
    Set-DhcpServerAuditLog -Enable $True -Path "C:\Windows\System32\Dhcp"
    Write-Host "DHCP Audit Logging Enabled." 
} catch {
    Write-Host "Failed to enable logging." 
}

# 3. Check AD Authorization
try {
    $authorized = Get-DhcpServerInDC -ErrorAction SilentlyContinue
    if ($authorized) {
        Write-Host "[OK] DHCP Server is authorized in Active Directory." 
    } else {
        Write-Host "[WARNING] DHCP Server is NOT authorized in AD! Clients may be blocked." 
    }
} catch {
    Write-Host "[INFO] Could not check AD Authorization (Machine might be standalone)."
}

# 4. Secure DNS Dynamic Updates
try {
    Set-DhcpServerv4DnsSetting `
        -DynamicUpdates Secure `
        -DeleteDnsRRonLeaseExpiry $true `
        -UpdateDnsRRForOlderClients $false
    Write-Host "Secure DNS dynamic updates enforced." 
} catch {
    Write-Host "Failed to set DNS Dynamic Updates." 
}

# 5. Check for Stored DNS Credentials (Risk Check)
$dnsCreds = Get-DhcpServerDnsCredential
if ($dnsCreds) {    
    $dnsCreds | Format-List
    Write-Host "Can run: Remove-DhcpServerDnsCredential" 
} else {
    Write-Host "No DHCP DNS credentials found." 
}

# 6. Enable Conflict Detection
Set-DhcpServerSetting -ConflictDetectionAttempts 2
Write-Host "Conflict detection set to 2 attempts."

# 7. Enable Name Protection
try {
    Get-DhcpServerv4Scope | Set-DhcpServerv4Scope -NameProtectionState Enable -ErrorAction SilentlyContinue
    Write-Host "Name Protection enabled on all scopes." 
} catch {
    Write-Host "[INFO] Name Protection could not be enabled (might not be supported on this scope)." 
}

# 8. Review DHCP Scopes (Manual Check)
Write-Host "`n REVIEW ACTIVE SCOPES (IPS?)" 
Get-DhcpServerv4Scope |
    Select-Object ScopeId, Name, State, LeaseDuration |
    Format-Table -AutoSize

# 9. Lock Down NIC Bindings
Write-Host "CHECKING NIC BINDINGS" 
Get-DhcpServerv4Binding | ForEach-Object {
    if ($_.BindingState) {
        Write-Host "ENABLED: $($_.InterfaceAlias) ($($_.IpAddress))" 
    } else {
        Write-Host "DISABLED: $($_.InterfaceAlias)"
    }
}

# 10. Review DHCP Filters
Write-Host "`n DHCP FILTERS" 
Get-DhcpServerv4Filter -List Allow -ErrorAction SilentlyContinue
Get-DhcpServerv4Filter -List Deny -ErrorAction SilentlyContinue

# 11. Backup DHCP Configuration 
$backupFolder = "C:\DHCP_Backup"
$backupFile = "$backupFolder\DhcpConfig_$(Get-Date -Format 'yyyyMMdd-HHmm').xml"

New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

try {
    Export-DhcpServer -ComputerName $env:COMPUTERNAME -File $backupFile -Force
    Write-Host "[OK] DHCP Configuration exported to: $backupFile" 
    Write-Host "      (Use 'Import-DhcpServer' to restore if needed)" 
} catch {
    Write-Host "[!!] ERROR: Backup failed: $_" 
}

# 12. Event Log Visibility 
try {
    Get-WinEvent -LogName "Microsoft-Windows-DHCP Server/Operational" -MaxEvents 5 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, Message | Format-Table -Wrap
} catch {
    Write-Host "No recent events found or log not active yet." 
}

Write-Host "`n COMPLETE" 