#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Enhanced DC Hardening Script (BlueShield-Lite)
.DESCRIPTION
    Integrates user management, firewall lockdown, protocol hardening, 
    and vulnerability patching (ZeroLogon, PrintNightmare, noPAC).
    INCLUDES EMERGENCY BACKUPS.
#>

#  Admin Check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "CRITICAL: You are NOT running as Administrator."
    Start-Sleep -Seconds 5
    exit
}

Clear-Host
$LogPath = "C:\Temp\AD_Hardening.log"
if (!(Test-Path "C:\Temp")) { New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null }

function Update-Log {
    param([string]$Action, [string]$Status)
    $Entry = "[$(Get-Date -Format 'HH:mm:ss')] - $Action - $Status"
    Add-Content -Path $LogPath -Value $Entry -Force
    Write-Host $Entry -ForegroundColor Cyan
}

# --- 1. EMERGENCY BACKUP (CRITICAL ADDITION) ---
function Emergency-Backup {
    Write-Host "`n--- Step 1: Emergency Backup (Safety Net) ---" -ForegroundColor Yellow
    $BackupPath = "C:\Backups_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    
    try {
        # Export Firewall Config
        netsh advfirewall export "$BackupPath\FirewallConfig.wfw"
        
        # Export Users & Groups
        Get-ADUser -Filter * -Properties * | Export-Csv "$BackupPath\Users.csv" -NoTypeInformation
        Get-ADGroup -Filter * | Export-Csv "$BackupPath\Groups.csv" -NoTypeInformation
        
        # Export GPOs
        Backup-Gpo -All -Path $BackupPath -ErrorAction SilentlyContinue
        
        Write-Host "SUCCESS: Backup saved to $BackupPath" -ForegroundColor Green
        Update-Log "Backup" "Completed at $BackupPath"
    } catch {
        Write-Error "Backup Failed: $($_.Exception.Message)"
        Update-Log "Backup" "FAILED: $($_.Exception.Message)"
        # We continue, but warn the user
        Start-Sleep -Seconds 3
    }
}

# --- 2. USER MANAGEMENT ---
function CreateAdmin {
    Write-Host "`n--- Step 2: Create NEW Admin User ---" -ForegroundColor Yellow
    
    $NewUser = Read-Host "Enter USERNAME for the new Admin"
    if ([string]::IsNullOrWhiteSpace($NewUser)) {
        Write-Warning "No username entered. Skipping creation."
        return
    }

    try {
        if (Get-ADUser -Filter {SamAccountName -eq $NewUser}) {
            Write-Warning "User '$NewUser' already exists. Promoting to Admin..."
            $UserObj = Get-ADUser $NewUser
        } else {
            $NewPass = Read-Host -AsSecureString "Enter PASSWORD for $NewUser"
            New-ADUser -Name $NewUser -SamAccountName $NewUser -AccountPassword $NewPass -Enabled $true -PasswordNeverExpires $true
            $UserObj = Get-ADUser $NewUser
            Write-Host "User '$NewUser' created successfully." -ForegroundColor Green
        }

        Add-ADGroupMember -Identity "Domain Admins" -Members $UserObj
        Add-ADGroupMember -Identity "Administrators" -Members $UserObj
        Add-ADGroupMember -Identity "Enterprise Admins" -Members $UserObj -ErrorAction SilentlyContinue
        $script:NewAdminName = $NewUser
        
        Update-Log "New-Admin" "Created/Promoted $NewUser"
    } catch {
        Update-Log "New-Admin" "ERROR: $($_.Exception.Message)"
    }
}

function Set-AdministratorAccount {
    Write-Host "`n--- Step 3: Secure Built-in Admin (SID-500) ---" -ForegroundColor Yellow
    try {
        $DomainSid = (Get-ADDomain).DomainSID.Value
        $AdminSid = New-Object System.Security.Principal.SecurityIdentifier ("$DomainSid-500")
        $AdminAccount = Get-ADUser -Identity $AdminSid
        
        if ($AdminAccount.Enabled -eq $false) { Enable-ADAccount -Identity $AdminAccount }
        
        $Pass = Read-Host -AsSecureString "Set NEW Password for Built-in Admin (Before Disabling)"
        Set-ADAccountPassword -Identity $AdminAccount -NewPassword $Pass
        Set-ADUser -Identity $AdminAccount -Description "Disabled by Hardening Script"
        Disable-ADAccount -Identity $AdminAccount
        
        Write-Host "Built-in Administrator Disabled." -ForegroundColor Red
        Update-Log "Admin" "SID-500 Secured and Disabled."
    } catch {
        Update-Log "Admin" "ERROR: $($_.Exception.Message)"
    }
}

function Disable-NonEssentialUsers {
    Write-Host "`n--- Step 4: Disable Non-Essential Users ---" -ForegroundColor Yellow
    $Criticals = @("Administrator", $script:NewAdminName) # add critical accounts
    
    $Users = Get-ADUser -Filter 'Enabled -eq $true' | Where-Object { $_.SamAccountName -notin $Criticals }
    
    # AUTOMATIC DISABLING
    foreach ($u in $Users) {
        try {
            Disable-ADAccount -Identity $u
            Write-Host "AUTO-DISABLED: $($u.SamAccountName)" -ForegroundColor Red
            Update-Log "User-Audit" "Automatically Disabled $($u.SamAccountName)"
        } catch {
            Write-Warning "Failed to disable $($u.SamAccountName): $($_.Exception.Message)"
            Update-Log "User-Audit" "FAILED to disable $($u.SamAccountName)"
        }
    }
}

# --- 3. VULNERABILITY PATCHING (NEW) ---
function Patch-Known-Vulns {
    Write-Host "`n--- Step 5: Patching Known Vulnerabilities ---" -ForegroundColor Yellow
    
    # PrintNightmare
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Set-Service Spooler -StartupType Disabled
    Write-Host "Print Spooler Disabled (PrintNightmare)" -ForegroundColor Green

    # ZeroLogon (Netlogon Hardening)
    $NetlogonPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
    Set-ItemProperty -Path $NetlogonPath -Name "FullSecureChannelProtection" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $NetlogonPath -Name "RequireStrongKey" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $NetlogonPath -Name "RequireSignOrSeal" -Value 1 -Type DWord -Force
    Write-Host "Netlogon Hardened (ZeroLogon)" -ForegroundColor Green

    # noPAC (MachineAccountQuota)
    try {
        Set-ADDomain -Identity ((Get-ADDomain).DistinguishedName) -Replace @{"ms-DS-MachineAccountQuota"="0"}
        Write-Host "MachineAccountQuota set to 0 (noPAC)" -ForegroundColor Green
    } catch { Write-Warning "Could not set MachineAccountQuota" }
    
    Update-Log "Vuln-Patch" "Applied PrintNightmare, ZeroLogon, noPAC fixes"
}

# --- 4. PROTOCOL HARDENING (NEW) ---
function Harden-Protocols {
    Write-Host "`n--- Step 6: Hardening Protocols ---" -ForegroundColor Yellow

    # Disable SMBv1
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    
    # Enforce SMB Signing
    Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction SilentlyContinue
    Set-SmbClientConfiguration -RequireSecuritySignature $true -Force -ErrorAction SilentlyContinue

    # Force NTLMv2 Only & Protect LSASS
    $LsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    Set-ItemProperty -Path $LsaPath -Name "LmCompatibilityLevel" -Value 5 -Type DWord -Force
    Set-ItemProperty -Path $LsaPath -Name "RunAsPPL" -Value 1 -Type DWord -Force

    Write-Host "SMBv1 Disabled, SMB Signing Enforced, NTLMv2 Forced, LSASS Protected." -ForegroundColor Green
    Update-Log "Protocols" "Hardened SMB, NTLM, LSASS"
}

# --- 5. SERVICE HARDENING (NEW) ---
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

function Configure-Firewall {
    Write-Host "`n--- Step 8: AD/DNS/DHCP Server Lockdown ---" -ForegroundColor Yellow
    
    # Reset to a clean state
    netsh advfirewall reset
    
    # Set default behaviors
    # Note: We keep blockoutbound, but we must be VERY precise with allow rules
    netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound
    
    # --- 1. MANDATORY: ICMP (Rule 14, Page 15) ---
    netsh advfirewall firewall add rule name="CCDC-ICMP-In" protocol=icmpv4 dir=in action=allow
    netsh advfirewall firewall add rule name="CCDC-ICMP-Out" protocol=icmpv4 dir=out action=allow

    # --- 2. DHCP ROLE (Required for Ubuntu Wkst) ---
    netsh advfirewall firewall add rule name="CCDC-DHCP-In" dir=in action=allow protocol=UDP localport=67
    netsh advfirewall firewall add rule name="CCDC-DHCP-Out" dir=out action=allow protocol=UDP remoteport=68

    # --- 3. DNS ROLE (Scored Service, Page 17) ---
    netsh advfirewall firewall add rule name="CCDC-DNS-In" dir=in action=allow protocol=UDP localport=53
    netsh advfirewall firewall add rule name="CCDC-DNS-TCP-In" dir=in action=allow protocol=TCP localport=53
    netsh advfirewall firewall add rule name="CCDC-DNS-Out" dir=out action=allow protocol=UDP remoteport=53

    # --- 4. AD AUTH ROLE (Required for Fedora Mail Scored Service) ---
    # Ports: 88(Kerberos), 135(RPC), 389/636(LDAP), 445(SMB), 3268/3269(Global Catalog)
    $ADPorts = "88,135,389,445,464,636,3268,3269"
    netsh advfirewall firewall add rule name="CCDC-AD-In" dir=in action=allow protocol=TCP localport=$ADPorts
    netsh advfirewall firewall add rule name="CCDC-AD-UDP-In" dir=in action=allow protocol=UDP localport=88,389,464
    
    # Outbound AD (Required for the DC to respond to auth requests)
    netsh advfirewall firewall add rule name="CCDC-AD-Out" dir=out action=allow protocol=TCP remoteport=$ADPorts

    # --- 5. RPC DYNAMIC PORTS (Required for AD functionality) ---
    netsh advfirewall firewall add rule name="CCDC-RPC-Dynamic-In" dir=in action=allow protocol=TCP localport=49152-65535
    netsh advfirewall firewall add rule name="CCDC-RPC-Dynamic-Out" dir=out action=allow protocol=TCP remoteport=49152-65535

    # --- 6. LOGGING (Outbound to Splunk 172.20.241.20) ---
    netsh advfirewall firewall add rule name="CCDC-Splunk-Out" dir=out action=allow protocol=TCP remoteport=9997
    netsh advfirewall firewall add rule name="CCDC-Syslog-Out" dir=out action=allow protocol=UDP remoteport=514

    # --- 7. NTP (Time Sync with Debian 172.20.240.20) ---
    netsh advfirewall firewall add rule name="CCDC-NTP-Out" dir=out action=allow protocol=UDP remoteport=123

    Update-Log "Firewall" "AD/DNS/DHCP specific rules applied. DHCP (67/68) enabled."
}

# --- 7. NETWORK & CERTS ---
function Disable-NetBIOS {
    Write-Host "`n--- Step 9: Disabling NetBIOS ---" -ForegroundColor Yellow
    try {
        $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        foreach ($adapter in $adapters) { $adapter.SetTcpipNetbios(2) | Out-Null }
        Write-Host "NetBIOS Disabled." -ForegroundColor Green
    } catch { Write-Warning "NetBIOS Error: $($_.Exception.Message)" }
}

function Disable-IPv6 {
    Write-Host "`n--- Step 10: Disabling IPv6 ---" -ForegroundColor Yellow
    Get-NetAdapter | ForEach-Object { Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -PassThru | Out-Null }
    Write-Host "IPv6 Disabled." -ForegroundColor Green
}

function Remove-ExpiredCertificates {
    Write-Host "`n--- Step 11: Cleaning Certificates ---" -ForegroundColor Yellow
    $ExpiredCerts = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.NotAfter -lt (Get-Date) }
    foreach ($cert in $ExpiredCerts) {
        Remove-Item $cert.PSPath
        Write-Host "Removed Expired Cert: $($cert.Thumbprint)" -ForegroundColor Red
    }
}

# --- EXECUTION FLOW ---
Emergency-Backup        # 1. Safety First
CreateAdmin             # 2. Secure Access
Set-AdministratorAccount # 3. Disable Built-in
Disable-NonEssentialUsers # 4. Reduce Surface
Patch-Known-Vulns       # 5. Fix CVEs
Harden-Protocols        # 6. Fix Registry/SMB
Disable-Weak-Services   # 7. Stop Lateral Movement
Configure-Firewall      # 8. Network Lockdown
Disable-NetBIOS         # 9. Legacy Network
Disable-IPv6            # 10. Legacy Network
Remove-ExpiredCertificates # 11. Hygiene

Write-Host "`n--- HARDENING COMPLETE ---" -ForegroundColor Cyan
Write-Host "Log file: $LogPath" -ForegroundColor Gray
gpupdate /force