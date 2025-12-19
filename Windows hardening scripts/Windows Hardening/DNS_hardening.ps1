#Requires -RunAsAdministrator
#Requires -Modules DnsServer

# --- 0. ADMIN CHECK ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "CRITICAL: You are NOT running as Administrator."
    Write-Warning "Right-click PowerShell and select 'Run as Administrator'."
    exit
}

Clear-Host
Write-Host "--- CCDC DNS HARDENING PROTOCOL (FINAL) ---" -ForegroundColor Cyan

# 1. Get Primary Zones (Excluding TrustAnchors)
try {
    $Zones = Get-DnsServerZone | Where-Object { $_.IsAutoCreated -eq $false -and $_.ZoneType -eq "Primary" -and $_.ZoneName -ne "TrustAnchors" }
} catch {
    Write-Error "Could not find DNS zones. Is the DNS Role installed?"
    exit
}

foreach ($Zone in $Zones) {
    $ZoneName = $Zone.ZoneName
    Write-Host "`nHardening Zone: $ZoneName" -ForegroundColor Yellow

    # --- A. DISABLE ZONE TRANSFERS ---
    # Prevents Reconnaissance
    try {
        Set-DnsServerPrimaryZone -Name $ZoneName -SecureSecondaries NoTransfer -ErrorAction Stop
        Write-Host " [OK] Zone Transfers DISABLED (NoTransfer)." -ForegroundColor Green
    } catch {
        Write-Host " [!!] Failed to disable Zone Transfers: $($_.Exception.Message)" -ForegroundColor Red
    }

    # --- B. SECURE DYNAMIC UPDATES ---
    # Prevents Poisoning
    try {
        Set-DnsServerPrimaryZone -Name $ZoneName -DynamicUpdate Secure -ErrorAction Stop
        Write-Host " [OK] Dynamic Updates set to SECURE." -ForegroundColor Green
    } catch {
        Write-Host " [!!] Failed to set Secure Updates: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- C. ENABLE CACHE LOCKING ---
Write-Host "`nConfiguring Cache Locking..." -ForegroundColor Yellow
try {
    Set-DnsServerCache -LockingPercent 100
    Write-Host " [OK] Cache Locking set to 100%." -ForegroundColor Green
} catch {
    Write-Host " [!!] Failed to set Cache Locking." -ForegroundColor Red
}

# --- D. RESPONSE RATE LIMITING (RRL) ---
# Mitigates Amplification Attacks
# USING DNSCMD (More robust on Server 2019 Eval)
Write-Host "`nConfiguring Response Rate Limiting (RRL)..." -ForegroundColor Yellow

try {
    $rrl = dnscmd /Config /RrlMode 1 2>&1
    if ($LASTEXITCODE -eq 0) {
        dnscmd /Config /RrlResponsesPerSec 5 | Out-Null
        dnscmd /Config /RrlErrorsPerSec 5 | Out-Null
        dnscmd /Config /RrlWindowInSeconds 5 | Out-Null
        Write-Host " [OK] RRL ENABLED via dnscmd." -ForegroundColor Green
    } else {
        throw "dnscmd failed"
    }
} catch {
    Write-Host " [!!] Failed to enable RRL. Ensure DNS Service is RUNNING." -ForegroundColor Red
}

# --- E. HIDE VERSION ---
Write-Host "`nHiding DNS Version..." -ForegroundColor Yellow
dnscmd /Config /EnableVersionQuery 0 | Out-Null
Write-Host " [OK] Version Hidden." -ForegroundColor Green

# --- F. RESTART SERVICE ---
Write-Host "`nRestarting DNS Service to apply changes..." -ForegroundColor Yellow
Restart-Service DNS
Write-Host "--- DNS HARDENING COMPLETE ---" -ForegroundColor Magenta


# --- G. DISABLE RECURSION (Or Secure it) ---
# Prevents DNS Tunneling and Amplification
Write-Host "`nConfiguring Recursion..." -ForegroundColor Yellow
try {
    # OPTION 1: Disable Recursion entirely (Safest if you rely on Forwarders)
    Set-DnsServerRecursion -Enable $false -ErrorAction Stop
    Write-Host " [OK] Recursion DISABLED (Server will only answer for local zones)." -ForegroundColor Green
    
    # OPTION 2: If you NEED recursion, ensure it doesn't use Root Hints (Use Forwarders only)
    # Set-DnsServerRecursion -Enable $true -UseRootHint $false
} catch {
    Write-Host " [!!] Failed to configure Recursion." -ForegroundColor Red
}

# --- H. GLOBAL QUERY BLOCK LIST (WPAD Protection) ---
# Prevents WPAD/ISATAP MitM attacks
Write-Host "`nConfiguring Global Query Block List (WPAD/ISATAP)..." -ForegroundColor Yellow
try {
    Set-DnsServerGlobalQueryBlockList -Enable $true -List @("wpad", "isatap") -ErrorAction Stop
    Write-Host " [OK] WPAD and ISATAP are globally BLOCKED." -ForegroundColor Green
} catch {
    Write-Host " [!!] Failed to set Block List." -ForegroundColor Red
}

# --- I. SOCKET POOL HARDENING ---
# Increases entropy against Cache Poisoning
Write-Host "`nHardening Socket Pool..." -ForegroundColor Yellow
try {
    # Default is usually 2500, increasing to 4000-10000 is better
    dnscmd /Config /SocketPoolSize 4000 | Out-Null
    Write-Host " [OK] Socket Pool increased to 4000." -ForegroundColor Green
} catch {
    Write-Host " [!!] Failed to set Socket Pool." -ForegroundColor Red
}

# --- J. ENABLE LOGGING (For Blue Team Awareness) ---
Write-Host "`nEnabling DNS Audit Logging..." -ForegroundColor Yellow
try {
    # This enables the high-volume analytical log. 
    # WARNING: In CCDC, this generates massive logs. Only enable if you are shipping logs to ELK/Splunk.
    # If no SIEM, stick to standard event logging.
    
    Set-DnsServerDiagnostics -EnableLogFileRollover $true -VerifyLevel 2
    Write-Host " [OK] Diagnostic logging levels increased." -ForegroundColor Green
} catch {
    Write-Host " [!!] Failed to enable logging." -ForegroundColor Red
}

# --- F. RESTART SERVICE (Keep this at the end) ---
Write-Host "`nRestarting DNS Service to apply changes..." -ForegroundColor Yellow
Restart-Service DNS
Write-Host "--- DNS HARDENING COMPLETE ---" -ForegroundColor Magenta