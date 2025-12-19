#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Enhanced Windows Server Hardening Script (Standalone/Member Server Edition)
.DESCRIPTION
    Integrates local user management, firewall lockdown, protocol hardening, 
    and vulnerability patching (ZeroLogon, PrintNightmare).
    DESIGNED FOR SERVERS WITHOUT AD/DNS ROLES.
#>

#  Admin Check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "CRITICAL: You are NOT running as Administrator."
    Start-Sleep -Seconds 5
    exit
}

Clear-Host
$LogPath = "C:\Temp\Server_Hardening.log"
if (!(Test-Path "C:\Temp")) { New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null }

function Update-Log {
    param([string]$Action, [string]$Status)
    $Entry = "[$(Get-Date -Format 'HH:mm:ss')] - $Action - $Status"
    Add-Content -Path $LogPath -Value $Entry -Force
    Write-Host $Entry -ForegroundColor Cyan
}

# --- 1. EMERGENCY BACKUP ---
function Emergency-Backup {
    Write-Host "`n--- Step 1: Emergency Backup (Local) ---" -ForegroundColor Yellow
    $BackupPath = "C:\Backups_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    
    try {
        # Export Firewall Config
        netsh advfirewall export "$BackupPath\FirewallConfig.wfw"
        
        # Export Local Users & Groups
        Get-LocalUser | Export-Csv "$BackupPath\LocalUsers.csv" -NoTypeInformation
        Get-LocalGroup | ForEach-Object { 
            $group = $_
            Get-LocalGroupMember -Group $group.Name | Select-Object @{N="GroupName";E={$group.Name}}, Name, PrincipalSource
        } | Export-Csv "$BackupPath\LocalGroupMembers.csv" -NoTypeInformation
        
        Write-Host "SUCCESS: Backup saved to $BackupPath" -ForegroundColor Green
        Update-Log "Backup" "Completed at $BackupPath"
    } catch {
        Write-Error "Backup Failed: $($_.Exception.Message)"
        Update-Log "Backup" "FAILED: $($_.Exception.Message)"
        Start-Sleep -Seconds 3
    }
}

# --- 2. USER MANAGEMENT ---
function CreateAdmin {
    Write-Host "`n--- Step 2: Create NEW Local Admin User ---" -ForegroundColor Yellow
    
    $NewUser = Read-Host "Enter USERNAME for the new Local Admin"
    if ([string]::IsNullOrWhiteSpace($NewUser)) {
        Write-Warning "No username entered. Skipping creation."
        return
    }

    try {
        if (Get-LocalUser -Name $NewUser -ErrorAction SilentlyContinue) {
            Write-Warning "User '$NewUser' already exists."
        } else {
            $NewPass = Read-Host -AsSecureString "Enter PASSWORD for $NewUser"
            New-LocalUser -Name $NewUser -Password $NewPass -Description "Admin created via Hardening Script" -PasswordNeverExpires $true
            Write-Host "User '$NewUser' created successfully." -ForegroundColor Green
        }

        Add-LocalGroupMember -Group "Administrators" -Member $NewUser
        $script:NewAdminName = $NewUser
        Update-Log "New-Admin" "Created/Promoted $NewUser to Local Administrators"
    } catch {
        Update-Log "New-Admin" "ERROR: $($_.Exception.Message)"
    }
}

function Set-AdministratorAccount {
    Write-Host "`n--- Step 3: Secure Built-in Local Admin ---" -ForegroundColor Yellow
    try {
        # Built-in local admin is always SID S-1-5-21-*-500, but we'll target by name "Administrator"
        $AdminAccount = Get-LocalUser -Name "Administrator"
        
        $Pass = Read-Host -AsSecureString "Set NEW Password for Built-in Administrator (Before Disabling)"
        Set-LocalUser -Name "Administrator" -Password $Pass
        Disable-LocalUser -Name "Administrator"
        
        Write-Host "Built-in Administrator Disabled." -ForegroundColor Red
        Update-Log "Admin" "Local Administrator account secured and disabled."
    } catch {
        Update-Log "Admin" "ERROR: $($_.Exception.Message)"
    }
}

function Disable-NonEssentialUsers {
    Write-Host "`n--- Step 4: Disable Non-Essential Local Users ---" -ForegroundColor Yellow
    # Keep the new admin, the Guest (already disabled usually), and DefaultAccount
    $Criticals = @("Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount", $script:NewAdminName) 
    
    $Users = Get-LocalUser | Where-Object { $_.Enabled -eq $true -and $_.Name -notin $Criticals }
    
    foreach ($u in $Users) {
        try {
            Disable-LocalUser -Name $u.Name
            Write-Host "DISABLED: $($u.Name)" -ForegroundColor Red
            Update-Log "User-Audit" "Disabled local user $($u.Name)"
        } catch {
            Write-Warning "Failed to disable $($u.Name)"
        }
    }
}

# --- 3. VULNERABILITY PATCHING ---
function Patch-Known-Vulns {
    Write-Host "`n--- Step 5: Patching Known Vulnerabilities ---" -ForegroundColor Yellow
    
    # PrintNightmare (Still relevant for standalone servers)
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Set-Service Spooler -StartupType Disabled
    Write-Host "Print Spooler Disabled (PrintNightmare)" -ForegroundColor Green

    # Netlogon Hardening (Relevant if server is a member of a domain, otherwise harmless)
    $NetlogonPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
    if (Test-Path $NetlogonPath) {
        Set-ItemProperty -Path $NetlogonPath -Name "FullSecureChannelProtection" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $NetlogonPath -Name "RequireStrongKey" -Value 1 -Type DWord -Force
        Write-Host "Netlogon Hardened" -ForegroundColor Green
    }
    
    Update-Log "Vuln-Patch" "Applied PrintNightmare and Netlogon registry fixes"
}

# --- 4. PROTOCOL HARDENING ---
function Harden-Protocols {
    Write-Host "`n--- Step 6: Hardening Protocols ---" -ForegroundColor Yellow

    # Disable SMBv1
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    
    # Enforce SMB Signing
    Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction SilentlyContinue

    # Force NTLMv2 Only & Protect LSASS
    $LsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    Set-ItemProperty -Path $LsaPath -Name "LmCompatibilityLevel" -Value 5 -Type DWord -Force
    Set-ItemProperty -Path $LsaPath -Name "RunAsPPL" -Value 1 -Type DWord -Force

    Write-Host "SMBv1 Disabled, SMB Signing Enforced, NTLMv2 Forced, LSASS Protected." -ForegroundColor Green
    Update-Log "Protocols" "Hardened SMB, NTLM, LSASS"
}

# --- 5. SERVICE HARDENING ---
function Disable-Weak-Services {
    Write-Host "`n--- Step 7: Disabling Weak Services ---" -ForegroundColor Yellow
    $Services = @("SSDPSRV", "upnphost", "WebClient", "MsraSvc", "TlntSvr", "SNMP")
    foreach ($svc in $Services) {
        if (Get-Service $svc -ErrorAction SilentlyContinue) {
            Stop-Service $svc -Force -ErrorAction SilentlyContinue
            Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "Disabled Service: $svc" -ForegroundColor Gray
        }
    }
    Update-Log "Services" "Disabled SSDP, UPnP, WebClient, etc."
}

# --- 6. FIREWALL (STANDALONE SERVER PROFILE) ---
function Configure-Firewall {
    Write-Host "`n--- Step 8: Standalone Server Firewall Lockdown ---" -ForegroundColor Yellow
    
    netsh advfirewall reset
    netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound
    
    # ICMP (Ping)
    netsh advfirewall firewall add rule name="CCDC-ICMP-In" protocol=icmpv4 dir=in action=allow
    netsh advfirewall firewall add rule name="CCDC-ICMP-Out" protocol=icmpv4 dir=out action=allow

    # DNS Outbound (To resolve updates/web)
    netsh advfirewall firewall add rule name="CCDC-DNS-Out" dir=out action=allow protocol=UDP remoteport=53
    netsh advfirewall firewall add rule name="CCDC-DNS-TCP-Out" dir=out action=allow protocol=TCP remoteport=53

    # HTTP/S Outbound (For Windows Updates)
    netsh advfirewall firewall add rule name="CCDC-Web-Out" dir=out action=allow protocol=TCP remoteport=80,443

    # RDP Inbound (WARNING: Ensure you need this before enabling)
    # netsh advfirewall firewall add rule name="CCDC-RDP-In" dir=in action=allow protocol=TCP localport=3389

    # NTP (Time Sync)
    netsh advfirewall firewall add rule name="CCDC-NTP-Out" dir=out action=allow protocol=UDP remoteport=123

    # Logging (Splunk/Syslog)
    netsh advfirewall firewall add rule name="CCDC-Logging-Out" dir=out action=allow protocol=TCP remoteport=9997
    netsh advfirewall firewall add rule name="CCDC-Syslog-Out" dir=out action=allow protocol=UDP remoteport=514

    Update-Log "Firewall" "Strict standalone profile applied. Inbound blocked except ICMP."
}

# --- 7. NETWORK HYGIENE ---
function Disable-NetBIOS {
    Write-Host "`n--- Step 9: Disabling NetBIOS ---" -ForegroundColor Yellow
    try {
        $adapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        foreach ($adapter in $adapters) { 
            Invoke-CimMethod -InputObject $adapter -MethodName SetTcpipNetbios -Arguments @{TcpipNetbiosOptions = 2} | Out-Null 
        }
        Write-Host "NetBIOS Disabled." -ForegroundColor Green
    } catch { Write-Warning "NetBIOS Error" }
}

function Disable-IPv6 {
    Write-Host "`n--- Step 10: Disabling IPv6 ---" -ForegroundColor Yellow
    Get-NetAdapter | ForEach-Object { Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue }
    Write-Host "IPv6 Disabled." -ForegroundColor Green
}

# --- EXECUTION FLOW ---
Emergency-Backup          # 1. Backup local state
CreateAdmin               # 2. Local Admin creation
Set-AdministratorAccount   # 3. Disable built-in local admin
Disable-NonEssentialUsers # 4. Disable other local users
Patch-Known-Vulns         # 5. Spooler and Reg fixes
Harden-Protocols          # 6. SMB/NTLM/LSASS
Disable-Weak-Services     # 7. Stop unnecessary services
Configure-Firewall        # 8. Lockdown network
Disable-NetBIOS           # 9. Network hygiene
Disable-IPv6              # 10. Network hygiene

Write-Host "`n--- HARDENING COMPLETE (STANDALONE MODE) ---" -ForegroundColor Cyan
Write-Host "Log file: $LogPath" -ForegroundColor Gray