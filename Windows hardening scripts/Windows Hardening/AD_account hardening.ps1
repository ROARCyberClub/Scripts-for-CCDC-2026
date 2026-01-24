#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory


# --- Admin Check ---
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

# --- Backup ---
function Emergency-Backup {
    Write-Host "`n--- Step 1: Emergency Backup ---" -ForegroundColor Yellow
    $BackupPath = "C:\Backups_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    
    try {
        netsh advfirewall export "$BackupPath\FirewallConfig.wfw"
        Get-ADUser -Filter * -Properties * | Export-Csv "$BackupPath\Users.csv" -NoTypeInformation
        Write-Host "SUCCESS: Backup saved to $BackupPath" -ForegroundColor Green
        Update-Log "Backup" "Completed"
    } catch {
        Update-Log "Backup" "FAILED: $($_.Exception.Message)"
    }
}

# --- User Management  ---
function CreateAdmin {
    Write-Host "`n--- Step 2: Create NEW Admin User ---" -ForegroundColor Yellow
    $NewUser = Read-Host "Enter USERNAME for the new Admin"
    if ([string]::IsNullOrWhiteSpace($NewUser)) { return }

    try {
        $NewPass = Read-Host -AsSecureString "Enter PASSWORD for $NewUser"
        New-ADUser -Name $NewUser -SamAccountName $NewUser -AccountPassword $NewPass -Enabled $true -PasswordNeverExpires $true
        Add-ADGroupMember -Identity "Domain Admins" -Members $NewUser
        Add-ADGroupMember -Identity "Administrators" -Members $NewUser
        $script:NewAdminName = $NewUser
        Update-Log "New-Admin" "Created $NewUser"
    } catch { Update-Log "New-Admin" "ERROR: $($_.Exception.Message)" }
}

function Set-AdministratorAccount {
    Write-Host "`n--- Step 3: Secure & Disable Built-in Admin (SID-500) ---" -ForegroundColor Yellow
    try {
        $AdminAccount = Get-ADUser -Filter "SID -like '*-500'"
        $ManualPass = Read-Host -Prompt "Enter a COMPLEX password to lock the SID-500 account" -AsSecureString
        Set-ADAccountPassword -Identity $AdminAccount -NewPassword $ManualPass 
        Disable-ADAccount -Identity $AdminAccount
        Write-Host "Built-in Administrator password set manually and account DISABLED." -ForegroundColor Red
        Update-Log "Admin" "SID-500 secured with manual password and disabled."
    } catch {
        Write-Host "CRITICAL ERROR: Failed to secure SID-500. $($_.Exception.Message)" -ForegroundColor White -BackgroundColor Red
        Update-Log "Admin" "ERROR: $($_.Exception.Message)"
    }
}

function Disable-NonEssentialUsers {
    Write-Host "`n--- Step 4: Whitelist & Disable Users ---" -ForegroundColor Yellow
    # Whitelist critical accounts. 
    # POP3 scoring relies on AD users 
    $Criticals = @("krbtgt", "Guest", $script:NewAdminName)
    $InputUsers = Read-Host "Enter Scored/POP3 usernames to Whitelist (comma separated)"
    if ($InputUsers) { $Criticals += $InputUsers.Split(',').Trim() }
    
    $Users = Get-ADUser -Filter 'Enabled -eq $true'
    foreach ($u in $Users) {
        if ($u.SamAccountName -notin $Criticals -and $u.SID -notlike "*-500") {
            Disable-ADAccount -Identity $u
            Write-Host "DISABLED: $($u.SamAccountName)" -ForegroundColor Red
        } else {
            # Ensure whitelisted users are enabled but NOT forced to change passwords
            Set-ADUser -Identity $u -ChangePasswordAtLogon $false
            Write-Host "WHITELISTED (Enabled): $($u.SamAccountName)" -ForegroundColor Green
        }
    }
}

# --- Hardening  ---
function Patch-Known-Vulns {
    Write-Host "`n--- Step 5: Patching Vulnerabilities ---" -ForegroundColor Yellow
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Set-Service Spooler -StartupType Disabled
    $NetlogonPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
    Set-ItemProperty -Path $NetlogonPath -Name "FullSecureChannelProtection" -Value 1 -Type DWord -Force
    try { Set-ADDomain -Identity ((Get-ADDomain).DistinguishedName) -Replace @{"ms-DS-MachineAccountQuota"="0"} } catch {}
}

function Harden-Protocols {
    Write-Host "`n--- Step 6: Hardening Protocols ---" -ForegroundColor Yellow
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 5 -Type DWord -Force
}

function Configure-Firewall {
    Write-Host "`n--- Step 7: Firewall Lockdown ---" -ForegroundColor Yellow
    netsh advfirewall reset
    # Setting Outbound to ALLOW to prevent breaking Injects/Proxy (Page 15)
    netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound
    
    # ICMP (Rule 14, Page 15)
    netsh advfirewall firewall add rule name="CCDC-ICMP-In" protocol=icmpv4 dir=in action=allow

    # DNS (Scored Service, Page 17)
    netsh advfirewall firewall add rule name="CCDC-DNS-In" dir=in action=allow protocol=UDP localport=53
    netsh advfirewall firewall add rule name="CCDC-DNS-TCP-In" dir=in action=allow protocol=TCP localport=53

    # AD & RPC Authentication
    $ADPorts = "88,135,389,445,464,636,3268,3269"
    netsh advfirewall firewall add rule name="CCDC-AD-In" dir=in action=allow protocol=TCP localport=$ADPorts
    netsh advfirewall firewall add rule name="CCDC-RPC-In" dir=in action=allow protocol=TCP localport=49152-65535

    # Splunk IP 
    netsh advfirewall firewall add rule name="CCDC-Splunk-Out" dir=out action=allow protocol=TCP remoteaddress=172.20.242.20 remoteport=9997
    Update-Log "Firewall" "Rules Applied"
}

# --- Disable NetBIOS ---
function Disable-NetBIOS {
    try {
        $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        foreach ($adapter in $adapters) { $adapter.SetTcpipNetbios(2) | Out-Null }
    } catch {}
}


function Disable-Weak-Services {
    Write-Host "`n--- Step 8: Disabling High-Risk Services ---" -ForegroundColor Yellow
    
    # High-Priority Services to Stop and Disable
    $Services = @(
        "RemoteRegistry", # Prevents remote registry dumping
        "WinRM",          # Stops PowerShell Remoting lateral movement
        "TermService",    # Double-secures RDP (since firewall is already blocking it)
        "WebClient",      # Prevents NTLM relay attacks
        "SSDPSRV",        # Simple Service Discovery (Not needed on a DC)
        "upnphost",       # UPnP (Security risk)
        "WSearch"         # Windows Search (High resource usage, indexing risk)
    )

    foreach ($svc in $Services) {
        if (Get-Service $svc -ErrorAction SilentlyContinue) {
            Stop-Service $svc -Force -ErrorAction SilentlyContinue
            Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "Service Disabled: $svc" -ForegroundColor Gray
        }
    }

    # Disable LLMNR (Prevents Responder/Man-in-the-Middle attacks)
    # This is a Registry fix, not a service.
    $DnsPath = "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient"
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    Set-ItemProperty -Path $DnsPath -Name "EnableMulticast" -Value 0 -Type DWord -Force
    Write-Host "LLMNR (Multicast DNS) Disabled via Registry." -ForegroundColor Green

    Update-Log "Services" "Disabled RemoteRegistry, WinRM, WebClient, and LLMNR."
}

# --- Functions called in Order ---
Emergency-Backup
CreateAdmin
Set-AdministratorAccount
Disable-NonEssentialUsers
Patch-Known-Vulns
Harden-Protocols
Configure-Firewall
Disable-NetBIOS
Disable-Weak-Services


Write-Host "`n--- HARDENING COMPLETE ---" -ForegroundColor Cyan
gpupdate /force