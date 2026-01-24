#Requires -RunAsAdministrator
#Requires -Modules DnsServer

Write-Host "--- DNS Hardening ---" -ForegroundColor Cyan


# Create Backup Directory
$BkpDir = "C:\Backups\DNS"
if (!(Test-Path $BkpDir)) { New-Item -ItemType Directory -Path $BkpDir -Force }

# 1. Export All Zones to .dns files (Flat Files)
$Zones = Get-DnsServerZone | Where-Object { $_.IsAutoCreated -eq $false -and $_.ZoneName -ne "TrustAnchors" }
foreach ($Zone in $Zones) {
    $ZoneName = $Zone.ZoneName
    # Export-DnsServerZone puts files in C:\Windows\System32\dns\
    Export-DnsServerZone -Name $ZoneName -FileName "$ZoneName.bak"
    # Move them to our safe backup folder
    Move-Item "C:\Windows\System32\dns\$ZoneName.bak" "$BkpDir\$ZoneName.dns" -Force
    Write-Host "Backed up Zone: $ZoneName" -ForegroundColor Green
}

# Backup DNS Server Registry Settings (RRL, Cache, etc.)
reg export "HKLM\SYSTEM\CurrentControlSet\Services\DNS\Parameters" "$BkpDir\DNS_Settings.reg" /y

Update-Log "Backup" "DNS Zones and Registry Settings saved to $BkpDir"

# --- Zone Security ---
# Using Get-DnsServerZone to capture all AD-integrated zones
$Zones = Get-DnsServerZone | Where-Object { $_.IsAutoCreated -eq $false -and $_.ZoneName -ne "TrustAnchors" }

foreach ($Zone in $Zones) {
    Write-Host "Updating Zone: $($Zone.ZoneName)" -ForegroundColor Yellow
    
    # Secure Transfers: Only allow to specific IPs (if you have a secondary) or None.
    Set-DnsServerZone -Name $Zone.ZoneName -ReplicationScope "Domain" -ErrorAction SilentlyContinue
    
    # Disable Transfers
    Set-DnsServerPrimaryZone -Name $Zone.ZoneName -SecureSecondaries NoTransfer -ErrorAction SilentlyContinue
    
    # Secure Updates 
    Set-DnsServerPrimaryZone -Name $Zone.ZoneName -DynamicUpdate Secure -ErrorAction SilentlyContinue
}

# --- Recursion and Forwarders ---
Write-Host "Configuring Forwarders & Recursion..." -ForegroundColor Yellow
# Ensure we point to a real DNS so the team can work
Set-DnsServerForwarder -IPAddress "1.1.1.1", "8.8.8.8" -PassThru

# Instead of disabling recursion, we enable it but keep it restricted.
Set-DnsServerRecursion -Enable $true -UseRootHint $false

# --- Cache and Socket Pool ---
Set-DnsServerCache -LockingPercent 100
dnscmd /Config /SocketPoolSize 4000 | Out-Null

# --- RRL  ---
# Increased to 15 to prevent accidental scoring drops
dnscmd /Config /RrlMode 1 | Out-Null
dnscmd /Config /RrlResponsesPerSec 15 | Out-Null 
dnscmd /Config /RrlErrorsPerSec 15 | Out-Null

# --- Global Query Block List ---
# Essential to stop LLMNR/mDNS/WPAD spoofing attacks
Set-DnsServerGlobalQueryBlockList -Enable $true -List @("wpad", "isatap")

# --- Hide Version ---
dnscmd /Config /EnableVersionQuery 0 | Out-Null

# --- Audit Logging ---
# We enable Event logging but NOT Analytical logging to save Disk I/O
Set-DnsServerDiagnostics -EnableLogging $true -SaveLogsToFullDiagnosticsFile $false

# --- Restart Service ---
Write-Host "Restarting DNS Service..." -ForegroundColor Magenta
Restart-Service DNS
Update-Log "DNS" "Hardening Applied. Recursion: Restricted, RRL: 15/s, Version: Hidden"

Write-Host "DNS Hardening Complete. Monitor NISE for uptime." -ForegroundColor Green